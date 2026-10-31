use std::io::Write;
use tokio::io::AsyncReadExt;

#[tokio::main]
async fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 3 {
        let msg = serde_json::json!({
            "type": "error",
            "message": "Usage: carbon-drop-engine <host> <file_path>"
        });
        println!("{}", msg);
        let _ = std::io::stdout().flush();
        std::process::exit(1);
    }

    let host_raw = args[1].trim();
    let host = host_raw.to_lowercase();
    let file_path = args[2].clone();

    let path = std::path::Path::new(&file_path);
    if !path.exists() {
        let msg = serde_json::json!({
            "type": "error",
            "message": format!("File not found: {}", file_path)
        });
        println!("{}", msg);
        let _ = std::io::stdout().flush();
        std::process::exit(1);
    }

    let metadata = match std::fs::metadata(path) {
        Ok(m) => m,
        Err(e) => {
            let msg = serde_json::json!({
                "type": "error",
                "message": format!("Cannot read file metadata: {}", e)
            });
            println!("{}", msg);
            let _ = std::io::stdout().flush();
            std::process::exit(1);
        }
    };

    let file_len = metadata.len();
    let total_mb = (file_len as f64) / (1024.0 * 1024.0);
    let file_name = path
        .file_name()
        .unwrap_or_default()
        .to_string_lossy()
        .to_string();
    let safe_file_name = file_name.replace(' ', "_");

    // Print initial progress immediately
    let initial_status = format!("0% (0.0 / {:.1} MB) • Starting...", total_mb);
    let init_progress = serde_json::json!({
        "type": "progress",
        "percent": 0.0,
        "status": initial_status
    });
    println!("{}", init_progress);
    let _ = std::io::stdout().flush();

    let mut cmd = tokio::process::Command::new("curl");
    cmd.arg("-g")
        .arg("--no-buffer")
        .arg("--connect-timeout")
        .arg("15")
        .arg("--max-time")
        .arg("7200");
    cmd.kill_on_drop(true);
    cmd.stdout(std::process::Stdio::piped());
    cmd.stderr(std::process::Stdio::piped());

    let mut filebin_target_url: Option<String> = None;

    if host.starts_with("buzz") || host.contains("buzz") {
        let url = format!("https://w.buzzheavier.com/{}", safe_file_name);
        cmd.arg("--retry")
            .arg("3")
            .arg("--retry-all-errors")
            .arg("--retry-delay")
            .arg("1")
            .arg("-L")
            .arg("-A")
            .arg("Mozilla/5.0")
            .arg("-T")
            .arg(&file_path)
            .arg(&url);
    } else if host.starts_with("filebin") || host.contains("filebin") {
        let bin_id = format!(
            "cb{}",
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_millis()
        );
        let url = format!("https://filebin.net/{}/{}", bin_id, safe_file_name);
        filebin_target_url = Some(url.clone());
        cmd.arg("-X")
            .arg("POST")
            .arg("-H")
            .arg("Accept: application/json")
            .arg("--data-binary")
            .arg(format!("@{}", file_path))
            .arg(&url);
    } else if host.starts_with("x0") || host.contains("x0") {
        cmd.arg("-A")
            .arg("CarbonDrop/1.0 (ArchLinux; Hyprland)")
            .arg("-F")
            .arg(format!("file=@{}", file_path))
            .arg("https://x0.at");
    } else if host.starts_with("uguu") || host.contains("uguu") {
        cmd.arg("-F")
            .arg(format!("files[]=@{}", file_path))
            .arg("https://uguu.se/upload");
    } else if host.starts_with("kappa") || host.contains("kappa") {
        cmd.arg("-F")
            .arg(format!("file=@{}", file_path))
            .arg("https://kappa.lol/api/upload");
    } else {
        cmd.arg("-A")
            .arg("CarbonDrop/1.0 (ArchLinux; Hyprland)")
            .arg("-F")
            .arg(format!("file=@{}", file_path))
            .arg("https://x0.at");
    }

    let mut child = match cmd.spawn() {
        Ok(c) => c,
        Err(e) => {
            let msg = serde_json::json!({
                "type": "error",
                "message": format!("Failed to start curl: {}", e)
            });
            println!("{}", msg);
            let _ = std::io::stdout().flush();
            std::process::exit(1);
        }
    };

    let engine_pid = std::process::id();
    let child_pid = child.id().unwrap_or(0);
    let init_info = serde_json::json!({
        "type": "init",
        "pid": engine_pid,
        "child_pid": child_pid
    });
    println!("{}", init_info);
    let _ = std::io::stdout().flush();

    let mut stderr = child.stderr.take().expect("Failed to open child stderr");
    let mut stdout = child.stdout.take().expect("Failed to open child stdout");

    // Concurrently read stderr stream
    let stderr_task = tokio::spawn(async move {
        let mut buf = [0u8; 1024];
        let mut line_buf = Vec::new();
        let mut last_pct = -1.0;

        while let Ok(n) = stderr.read(&mut buf).await {
            if n == 0 {
                break;
            }
            for &b in &buf[..n] {
                if b == b'\r' || b == b'\n' {
                    if !line_buf.is_empty() {
                        let s = String::from_utf8_lossy(&line_buf);
                        let parts: Vec<&str> = s.split_whitespace().collect();
                        if !parts.is_empty() {
                            if let Ok(pct) = parts[0].parse::<f64>() {
                                let speed = parts.last().unwrap_or(&"--");
                                let eta = if parts.len() >= 12 { parts[10] } else { "--:--:--" };
                                let current_mb = total_mb * (pct / 100.0);
                                let status = format!(
                                    "{:.0}% ({:.1} / {:.1} MB) • {}/s • ETA {}",
                                    pct, current_mb, total_mb, speed, eta
                                );

                                if (pct - last_pct).abs() >= 0.5 || pct >= 100.0 {
                                    last_pct = pct;
                                    let json_msg = serde_json::json!({
                                        "type": "progress",
                                        "percent": pct,
                                        "status": status
                                    });
                                    println!("{}", json_msg);
                                    let _ = std::io::stdout().flush();
                                }
                            }
                        }
                        line_buf.clear();
                    }
                } else {
                    line_buf.push(b);
                }
            }
        }
    });

    // Concurrently read stdout stream
    let stdout_task = tokio::spawn(async move {
        let mut stdout_buf = Vec::new();
        let _ = stdout.read_to_end(&mut stdout_buf).await;
        stdout_buf
    });

    // Join concurrently to prevent pipe buffer deadlock
    let (wait_res, _, stdout_res) = tokio::join!(child.wait(), stderr_task, stdout_task);
    let stdout_bytes = stdout_res.unwrap_or_default();
    let stdout_str = String::from_utf8_lossy(&stdout_bytes).to_string();

    let exit_success = wait_res.as_ref().map(|s| s.success()).unwrap_or(false);

    let final_url: Option<String> = if exit_success {
        if host.starts_with("buzz") || host.contains("buzz") {
            serde_json::from_str::<serde_json::Value>(&stdout_str)
                .ok()
                .and_then(|v| {
                    v.pointer("/data/id")
                        .and_then(|x| x.as_str())
                        .map(|id| format!("https://buzzheavier.com/{}", id))
                })
        } else if host.starts_with("filebin") || host.contains("filebin") {
            if stdout_str.contains("filename") || stdout_str.contains("bin") {
                filebin_target_url
            } else {
                None
            }
        } else if host.starts_with("x0") || host.contains("x0") {
            let trimmed = stdout_str.trim().to_string();
            if trimmed.starts_with("http") {
                Some(trimmed)
            } else {
                None
            }
        } else if host.starts_with("uguu") || host.contains("uguu") {
            serde_json::from_str::<serde_json::Value>(&stdout_str)
                .ok()
                .and_then(|v| {
                    v.pointer("/files/0/url")
                        .and_then(|x| x.as_str())
                        .map(|u| u.to_string())
                })
        } else if host.starts_with("kappa") || host.contains("kappa") {
            serde_json::from_str::<serde_json::Value>(&stdout_str)
                .ok()
                .and_then(|v| {
                    v.get("link").and_then(|x| x.as_str()).map(|link| {
                        let ext = v.get("ext").and_then(|x| x.as_str()).unwrap_or("");
                        format!("{}{}", link, ext)
                    })
                })
        } else {
            let trimmed = stdout_str.trim().to_string();
            if trimmed.starts_with("http") {
                Some(trimmed)
            } else {
                None
            }
        }
    } else {
        None
    };

    if let Some(url) = final_url {
        let msg = serde_json::json!({
            "type": "complete",
            "url": url
        });
        println!("{}", msg);
        let _ = std::io::stdout().flush();
    } else {
        let err_text = format!("Upload failed (exit: {:?}): {}", wait_res, stdout_str.trim());
        let msg = serde_json::json!({
            "type": "error",
            "message": err_text
        });
        println!("{}", msg);
        let _ = std::io::stdout().flush();
        std::process::exit(1);
    }
}
