use std::path::PathBuf;
use std::pin::Pin;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::Arc;
use std::task::{Context, Poll};
use std::time::Duration;

use i_slint_backend_winit::{EventResult, WinitWindowAccessor};
use reqwest::multipart::{Form, Part};
use slint::ComponentHandle;
use tokio::io::AsyncRead;
use tokio::task::JoinHandle;

slint::include_modules!();

pub type AppWindow = MainWindow;

pub mod slint_compat {
    use std::path::{Path, PathBuf};

    pub struct DroppedFile {
        pub path: PathBuf,
    }

    impl DroppedFile {
        pub fn path(&self) -> &Path {
            &self.path
        }
    }

    pub struct DropEvent {
        pub files: Vec<DroppedFile>,
    }

    pub enum WindowEvent {
        Drop(DropEvent),
        Hover,
    }
}

pub trait SlintWindowDropExt {
    fn on_window_event(&self, f: impl FnMut(slint_compat::WindowEvent) + 'static);
    fn set_clipboard_text(&self, text: &str);
}

impl SlintWindowDropExt for ::slint::Window {
    fn on_window_event(&self, mut f: impl FnMut(slint_compat::WindowEvent) + 'static) {
        self.on_winit_window_event(move |_window, event| {
            if let winit::event::WindowEvent::DroppedFile(path) = event {
                let drop_event = slint_compat::DropEvent {
                    files: vec![slint_compat::DroppedFile { path: path.clone() }],
                };
                f(slint_compat::WindowEvent::Drop(drop_event));
            }
            EventResult::Propagate
        });
    }

    fn set_clipboard_text(&self, text: &str) {
        copy_to_clipboard(text);
    }
}

mod slint_mod {
    pub use ::slint::*;
    pub use crate::slint_compat::WindowEvent;
}
use slint_mod as slint;


/// Helper to generate SVG Arc Path commands for circular progress
fn calculate_arc_path(progress: f32) -> String {
    let p = progress.clamp(0.0, 1.0);
    if p <= 0.005 {
        return "M 40 8".to_string();
    }
    if p >= 0.999 {
        return "M 40 8 A 32 32 0 1 1 39.99 8 Z".to_string();
    }
    let angle = p * 2.0 * std::f32::consts::PI;
    let x = 40.0 + 32.0 * angle.sin();
    let y = 40.0 - 32.0 * angle.cos();
    let large_arc = if p > 0.5 { 1 } else { 0 };
    format!("M 40 8 A 32 32 0 {} 1 {:.2} {:.2}", large_arc, x, y)
}

/// Custom AsyncRead wrapper to track upload progress and support pause
#[allow(dead_code)]
struct ProgressReader<R> {
    inner: R,
    uploaded: Arc<AtomicU64>,
    total: u64,
    progress_tx: tokio::sync::mpsc::Sender<f32>,
    paused: Arc<AtomicBool>,
}

impl<R: AsyncRead + Unpin> AsyncRead for ProgressReader<R> {
    fn poll_read(
        mut self: Pin<&mut Self>,
        cx: &mut Context<'_>,
        buf: &mut tokio::io::ReadBuf<'_>,
    ) -> Poll<std::io::Result<()>> {
        // If upload is paused, register interest and wait
        if self.paused.load(Ordering::Relaxed) {
            let waker = cx.waker().clone();
            tokio::spawn(async move {
                tokio::time::sleep(Duration::from_millis(100)).await;
                waker.wake();
            });
            return Poll::Pending;
        }

        let prev_len = buf.filled().len();
        match Pin::new(&mut self.inner).poll_read(cx, buf) {
            Poll::Ready(Ok(())) => {
                let bytes_read = buf.filled().len() - prev_len;
                if bytes_read > 0 {
                    let total_uploaded = self
                        .uploaded
                        .fetch_add(bytes_read as u64, Ordering::Relaxed)
                        + bytes_read as u64;
                    if self.total > 0 {
                        let pct = (total_uploaded as f32 / self.total as f32).clamp(0.0, 1.0);
                        let _ = self.progress_tx.try_send(pct);
                    }
                }
                Poll::Ready(Ok(()))
            }
            other => other,
        }
    }
}

/// Shared upload controller state
#[derive(Clone, Default)]
struct AppController {
    current_task: Arc<tokio::sync::Mutex<Option<JoinHandle<()>>>>,
    paused_flag: Arc<AtomicBool>,
}

impl AppController {
    fn cancel(&self) {
        let task_arc = self.current_task.clone();
        let paused = self.paused_flag.clone();
        paused.store(false, Ordering::Relaxed);
        tokio::spawn(async move {
            let mut guard = task_arc.lock().await;
            if let Some(handle) = guard.take() {
                handle.abort();
            }
        });
    }

    fn toggle_pause(&self) -> bool {
        let current = self.paused_flag.load(Ordering::Relaxed);
        let new_state = !current;
        self.paused_flag.store(new_state, Ordering::Relaxed);
        new_state
    }
}

/// Dispatches an async streaming upload to the chosen API
#[allow(dead_code)]
async fn upload_file(
    file_path: PathBuf,
    api_name: String,
    ui_weak: slint::Weak<MainWindow>,
    paused_flag: Arc<AtomicBool>,
) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
    let file = tokio::fs::File::open(&file_path).await?;
    let metadata = file.metadata().await?;
    let total_size = metadata.len();

    let file_name = file_path
        .file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_else(|| "unnamed_file".to_string());

    let mime_type = mime_guess::from_path(&file_path)
        .first_or_octet_stream()
        .to_string();

    let (progress_tx, mut progress_rx) = tokio::sync::mpsc::channel::<f32>(100);
    let uploaded_bytes = Arc::new(AtomicU64::new(0));

    // Spawn a listener task to deliver UI updates on the Slint event loop
    let ui_weak_progress = ui_weak.clone();
    let progress_listener = tokio::spawn(async move {
        let mut last_reported = 0.0f32;
        while let Some(pct) = progress_rx.recv().await {
            if (pct - last_reported).abs() > 0.005 || pct >= 0.999 {
                last_reported = pct;
                let ui_weak = ui_weak_progress.clone();
                let _ = slint::invoke_from_event_loop(move || {
                    if let Some(ui) = ui_weak.upgrade() {
                        ui.set_upload_progress(pct);
                        ui.set_arc_path(calculate_arc_path(pct).into());
                    }
                });
            }
        }
    });

    let reader = ProgressReader {
        inner: file,
        uploaded: uploaded_bytes,
        total: total_size,
        progress_tx,
        paused: paused_flag,
    };

    let stream = tokio_util::io::ReaderStream::new(reader);
    let body = reqwest::Body::wrap_stream(stream);
    let part = Part::stream_with_length(body, total_size)
        .file_name(file_name.clone())
        .mime_str(&mime_type)?;

    let client = reqwest::Client::builder()
        .user_agent("Mozilla/5.0 (X11; Linux x86_64) CarbonDrop/1.0")
        .timeout(Duration::from_secs(300))
        .build()?;

    let final_url = match api_name.as_str() {
        "0x0.st" => {
            let form = Form::new().part("file", part);
            let res = client.post("https://0x0.st").multipart(form).send().await?;

            if !res.status().is_success() {
                let status = res.status();
                let text = res.text().await.unwrap_or_default();
                return Err(format!("0x0.st error {}: {}", status, text.trim()).into());
            }
            res.text().await?.trim().to_string()
        }
        "Litterbox" => {
            let form = Form::new()
                .text("reqtype", "fileupload")
                .text("time", "1h")
                .part("fileToUpload", part);

            let res = client
                .post("https://litterbox.catbox.moe/resources/internals/api.php")
                .multipart(form)
                .send()
                .await;

            let maybe_url = match res {
                Ok(r) if r.status().is_success() => {
                    let text = r.text().await.unwrap_or_default().trim().to_string();
                    if text.starts_with("http://") || text.starts_with("https://") {
                        Some(text)
                    } else {
                        None
                    }
                }
                _ => None,
            };

            if let Some(url) = maybe_url {
                url
            } else {
                // Fallback to catbox.moe user API if litterbox returns 403 / WAF block
                let file_fb = tokio::fs::File::open(&file_path).await?;
                let part_fb = Part::stream_with_length(
                    reqwest::Body::wrap_stream(tokio_util::io::ReaderStream::new(file_fb)),
                    total_size,
                )
                .file_name(file_name)
                .mime_str(&mime_type)?;

                let fb_form = Form::new()
                    .text("reqtype", "fileupload")
                    .part("fileToUpload", part_fb);

                let fb_res = client
                    .post("https://catbox.moe/user/api.php")
                    .multipart(fb_form)
                    .send()
                    .await?;

                if fb_res.status().is_success() {
                    let out = fb_res.text().await?.trim().to_string();
                    if out.starts_with("http") {
                        out
                    } else {
                        return Err(format!("Catbox returned: {}", out).into());
                    }
                } else {
                    return Err(format!("Upload failed with status {}", fb_res.status()).into());
                }
            }
        }
        "file.io" => {
            let form = Form::new().part("file", part);
            let res = client
                .post("https://file.io/")
                .multipart(form)
                .send()
                .await?;

            if !res.status().is_success() {
                let status = res.status();
                let text = res.text().await.unwrap_or_default();
                return Err(format!("file.io error {}: {}", status, text.trim()).into());
            }

            let json: serde_json::Value = res.json().await?;
            if let Some(link) = json.get("link").and_then(|v| v.as_str()) {
                link.to_string()
            } else if let Some(msg) = json.get("message").and_then(|v| v.as_str()) {
                return Err(format!("file.io: {}", msg).into());
            } else {
                return Err("Failed to parse link from file.io response".into());
            }
        }
        _ => return Err(format!("Unsupported API: {}", api_name).into()),
    };

    progress_listener.abort();
    Ok(final_url)
}

/// Triggers upload of a file path
fn start_upload(ui: &MainWindow, path: PathBuf, controller: &AppController) {
    if !path.exists() || !path.is_file() {
        return;
    }

    let file_name = path
        .file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_else(|| "file".to_string());

    let api_name = ui.get_active_api().to_string();

    ui.set_app_state(1);
    ui.set_state(AppState::Uploading);
    ui.set_upload_progress(0.0);
    ui.set_arc_path(calculate_arc_path(0.0).into());
    ui.set_file_name(file_name.into());
    ui.set_status_message("".into());
    ui.set_is_paused(false);
    ui.set_link_copied(false);

    controller.paused_flag.store(false, Ordering::Relaxed);

    let ui_weak = ui.as_weak();
    let file_path = path.to_string_lossy().to_string();
    let active_api_string = api_name;

    let task = tokio::spawn(async move {
        let mut cmd = tokio::process::Command::new("curl");
        cmd.arg("-sS"); // Do NOT use -L on POST requests as it converts POST to GET on 301/302!

        match active_api_string.as_str() {
            "0x0.st" => {
                cmd.arg("-A").arg("CarbonDrop/1.0")
                   .arg("-F").arg(format!("file=@\"{}\"", file_path))
                   .arg("https://0x0.st");
            }
            "Litterbox" => {
                cmd.arg("-L")
                   .arg("-H").arg("User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0")
                   .arg("-H").arg("Origin: https://litterbox.catbox.moe")
                   .arg("-H").arg("Referer: https://litterbox.catbox.moe/")
                   .arg("-F").arg("reqtype=fileupload")
                   .arg("-F").arg("time=1h")
                   .arg("-F").arg(format!("fileToUpload=@\"{}\"", file_path))
                   .arg("https://litterbox.catbox.moe/resources/internals/api.php");
            }
            "file.io" => {
                cmd.arg("-L")
                   .arg("--post301").arg("--post302").arg("--post303") // Keep POST method across redirects!
                   .arg("-H").arg("Accept: application/json")
                   .arg("-H").arg("User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0")
                   .arg("-F").arg(format!("file=@\"{}\"", file_path))
                   .arg("https://file.io/");
            }
            _ => return,
        }

        let output = cmd.output().await;

        let final_url = match output {
            Ok(out) => {
                let stdout = String::from_utf8_lossy(&out.stdout).trim().to_string();
                let stderr = String::from_utf8_lossy(&out.stderr).trim().to_string();
                
                if !out.status.success() || stdout.is_empty() {
                    format!("Error: {}", if stderr.is_empty() { "Upload failed" } else { &stderr })
                } else if stdout.starts_with("<!") || stdout.starts_with("<html") {
                    // Print the first 300 characters of stdout to terminal so we can debug if blocked
                    eprintln!("API returned HTML:\n{}", &stdout[..stdout.len().min(300)]);
                    "Error: Cloudflare challenge on host (Try 0x0.st)".to_string()
                } else if active_api_string == "file.io" {
                    if let Ok(json) = serde_json::from_str::<serde_json::Value>(&stdout) {
                        json["link"].as_str().unwrap_or("Error: No link in JSON").to_string()
                    } else {
                        stdout
                    }
                } else {
                    stdout
                }
            }
            Err(e) => format!("Error executing curl: {}", e),
        };

        // Send final_url back to Slint and set state to Success
        let _ = slint::invoke_from_event_loop(move || {
            if let Some(ui) = ui_weak.upgrade() {
                ui.set_app_state(2);
                ui.set_state(AppState::Success);
                ui.set_upload_progress(1.0);
                ui.set_arc_path(calculate_arc_path(1.0).into());
                ui.set_final_url(final_url.clone().into());
                ui.set_result_url(final_url.into());
            }
        });
    });

    let current_task_arc = controller.current_task.clone();
    tokio::spawn(async move {
        let mut guard = current_task_arc.lock().await;
        *guard = Some(task);
    });
}

fn copy_to_clipboard(text: &str) {
    // Try arboard first
    if let Ok(mut clip) = arboard::Clipboard::new() {
        let _ = clip.set_text(text);
    }
    // Also use wl-copy for Wayland compositor support
    let _ = std::process::Command::new("wl-copy")
        .arg(text)
        .spawn();
}

fn urlencoding_decode(s: &str) -> String {
    let mut result = String::with_capacity(s.len());
    let mut chars = s.chars().peekable();
    while let Some(c) = chars.next() {
        if c == '%' {
            let hex: String = chars.by_ref().take(2).collect();
            if hex.len() == 2 {
                if let Ok(byte) = u8::from_str_radix(&hex, 16) {
                    result.push(byte as char);
                    continue;
                }
            }
            result.push('%');
            result.push_str(&hex);
        } else if c == '+' {
            result.push(' ');
        } else {
            result.push(c);
        }
    }
    result
}

fn get_clipboard_file_path() -> Option<PathBuf> {
    let output = std::process::Command::new("wl-paste")
        .arg("-t")
        .arg("text/uri-list")
        .output()
        .ok();

    let text = match output {
        Some(out) if out.status.success() && !out.stdout.is_empty() => {
            String::from_utf8_lossy(&out.stdout).to_string()
        }
        _ => {
            let plain_out = std::process::Command::new("wl-paste").output().ok();
            match plain_out {
                Some(out) if out.status.success() => String::from_utf8_lossy(&out.stdout).to_string(),
                _ => String::new(),
            }
        }
    };

    for line in text.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }

        let raw_path = if let Some(stripped) = line.strip_prefix("file://") {
            stripped
        } else {
            line
        };

        let decoded = urlencoding_decode(raw_path);
        let path = PathBuf::from(&decoded);
        if path.exists() {
            return Some(path);
        }
    }

    None
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    std::env::set_var("WINIT_UNIX_BACKEND", "x11");

    // Initialize Tokio multithreaded runtime
    let rt = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()?;
    let _guard = rt.enter();

    let ui = AppWindow::new().unwrap();
    let controller = AppController::default();

    // Start upload callback handler
    let ui_weak_upload = ui.as_weak();
    let controller_upload = controller.clone();
    ui.on_start_upload(move |file_path_slint| {
        let path = PathBuf::from(file_path_slint.as_str());
        if let Some(ui) = ui_weak_upload.upgrade() {
            start_upload(&ui, path, &controller_upload);
        }
    });

    // Paste from clipboard callback handler
    let ui_weak_paste = ui.as_weak();
    let controller_paste = controller.clone();
    ui.on_paste_from_clipboard(move || {
        if let Some(path) = get_clipboard_file_path() {
            if let Some(ui) = ui_weak_paste.upgrade() {
                start_upload(&ui, path, &controller_paste);
            }
        }
    });

    // 1. API Switcher Callback
    let ui_weak = ui.as_weak();
    ui.on_select_api(move |api_name| {
        if let Some(ui) = ui_weak.upgrade() {
            ui.set_active_api(api_name);
        }
    });

    // 2. Browse / Open File Dialog Callbacks
    let ui_weak = ui.as_weak();
    let controller_browse = controller.clone();
    ui.on_open_file_dialog({
        let ui_weak = ui_weak.clone();
        let controller = controller_browse.clone();
        move || {
            let ui_weak = ui_weak.clone();
            let controller = controller.clone();
            tokio::spawn(async move {
                let file = rfd::AsyncFileDialog::new()
                    .set_title("Select File to Upload")
                    .pick_file()
                    .await;

                if let Some(handle) = file {
                    let path = handle.path().to_path_buf();
                    let _ = slint::invoke_from_event_loop(move || {
                        if let Some(ui) = ui_weak.upgrade() {
                            start_upload(&ui, path, &controller);
                        }
                    });
                }
            });
        }
    });

    let ui_weak_browse = ui.as_weak();
    let controller_browse2 = controller.clone();
    ui.on_browse_clicked(move || {
        let ui_weak = ui_weak_browse.clone();
        let controller = controller_browse2.clone();
        tokio::spawn(async move {
            let file = rfd::AsyncFileDialog::new()
                .set_title("Select File to Upload")
                .pick_file()
                .await;

            if let Some(handle) = file {
                let path = handle.path().to_path_buf();
                let _ = slint::invoke_from_event_loop(move || {
                    if let Some(ui) = ui_weak.upgrade() {
                        start_upload(&ui, path, &controller);
                    }
                });
            }
        });
    });

    // 3. Cancel Upload Callback
    let ui_weak = ui.as_weak();
    let controller_cancel = controller.clone();
    ui.on_cancel_upload(move || {
        controller_cancel.cancel();
        if let Some(ui) = ui_weak.upgrade() {
            ui.set_state(AppState::Idle);
            ui.set_upload_progress(0.0);
            ui.set_arc_path(calculate_arc_path(0.0).into());
            ui.set_is_paused(false);
            ui.set_file_name("".into());
            ui.set_status_message("Upload cancelled".into());
        }
    });

    // 4. Pause / Resume Toggle Callback
    let ui_weak = ui.as_weak();
    let controller_pause = controller.clone();
    ui.on_pause_toggle(move || {
        let is_paused = controller_pause.toggle_pause();
        if let Some(ui) = ui_weak.upgrade() {
            ui.set_is_paused(is_paused);
        }
    });

    // 5. Copy Clipboard Callbacks
    let ui_weak = ui.as_weak();
    ui.on_copy_to_clipboard({
        let ui_weak = ui_weak.clone();
        move |text| {
            let text_str = text.to_string();
            if let Some(ui) = ui_weak.upgrade() {
                ui.window().set_clipboard_text(&text_str);
            }
            // Native Wayland clipboard fallback
            if let Ok(mut child) = std::process::Command::new("wl-copy")
                .stdin(std::process::Stdio::piped())
                .spawn()
            {
                if let Some(mut stdin) = child.stdin.take() {
                    use std::io::Write;
                    let _ = stdin.write_all(text_str.as_bytes());
                }
            }
        }
    });

    let ui_weak = ui.as_weak();
    ui.on_copy_link(move || {
        if let Some(ui) = ui_weak.upgrade() {
            let url = ui.get_final_url().to_string();
            let url = if url.is_empty() { ui.get_result_url().to_string() } else { url };
            if !url.is_empty() {
                copy_to_clipboard(&url);
                ui.set_link_copied(true);

                let ui_weak_timer = ui_weak.clone();
                slint::Timer::single_shot(Duration::from_secs(2), move || {
                    if let Some(ui) = ui_weak_timer.upgrade() {
                        ui.set_link_copied(false);
                    }
                });
            }
        }
    });

    // 6. Reset State / New Upload Callback
    let ui_weak = ui.as_weak();
    ui.on_reset_state(move || {
        if let Some(ui) = ui_weak.upgrade() {
            ui.set_state(AppState::Idle);
            ui.set_app_state(0);
            ui.set_upload_progress(0.0);
            ui.set_arc_path(calculate_arc_path(0.0).into());
            ui.set_file_name("".into());
            ui.set_final_url("".into());
            ui.set_result_url("".into());
            ui.set_status_message("".into());
            ui.set_is_paused(false);
            ui.set_link_copied(false);
        }
    });

    // 7. Close Window Callback
    let ui_weak = ui.as_weak();
    ui.on_close_window(move || {
        if let Some(ui) = ui_weak.upgrade() {
            let _ = ui.hide();
        }
        std::process::exit(0);
    });

    // Command line argument support: carbon-drop <file_path> [--api <api>]
    let args: Vec<String> = std::env::args().collect();
    let mut file_arg = None;
    let mut api_arg = None;
    let mut i = 1;
    while i < args.len() {
        if args[i] == "--api" && i + 1 < args.len() {
            api_arg = Some(args[i + 1].clone());
            i += 2;
        } else if !args[i].starts_with('-') {
            file_arg = Some(args[i].clone());
            i += 1;
        } else {
            i += 1;
        }
    }

    if let Some(api) = api_arg {
        ui.set_active_api(api.into());
    }

    if let Some(arg) = file_arg {
        let path = PathBuf::from(arg);
        if path.exists() && path.is_file() {
            let ui_weak_cli = ui.as_weak();
            let controller_cli = controller.clone();
            slint::Timer::single_shot(Duration::from_millis(60), move || {
                if let Some(ui) = ui_weak_cli.upgrade() {
                    start_upload(&ui, path, &controller_cli);
                }
            });
        }
    }

    let ui_handle = ui.as_weak();
    ui.window().on_window_event(move |event| {
        if let slint::WindowEvent::Drop(drop_event) = event {
            if let Some(file) = drop_event.files.first() {
                let file_path = file.path().to_string_lossy().to_string();
                if let Some(ui) = ui_handle.upgrade() {
                    ui.set_app_state(1); // Transition to Uploading state
                    // Trigger the async upload task with file_path
                    ui.invoke_start_upload(file_path.into());
                }
            }
        }
    });

    // Run Slint Event Loop
    ui.run()?;
    Ok(())
}