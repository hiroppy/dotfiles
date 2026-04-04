use std::process::Command;

/// All git information gathered in a single background pass
#[derive(Debug, Clone, Default)]
pub struct GitData {
    pub status_lines: Vec<String>,
    pub diff_stat: Option<(usize, usize)>,
    pub branch: String,
    pub ahead_behind: Option<(usize, usize)>,
    pub last_commit: Option<(String, String, u64)>,
    pub file_changes: Vec<(String, usize)>,
    pub remote_url: String,
    pub pr_number: Option<String>,
}

/// Fetch all git data for a given path. Runs blocking subprocess calls.
/// Designed to be called from a background thread.
pub fn fetch_git_data(path: &str) -> GitData {
    let mut data = GitData::default();

    if let Some(text) = run_git(path, &["status", "--short"]) {
        data.status_lines = text.lines().map(|l| l.to_string()).collect();
    }

    if let Some(text) = run_git(path, &["diff", "--shortstat"]) {
        data.diff_stat = parse_diff_stat(&text);
    }

    if let Some(text) = run_git(path, &["rev-parse", "--abbrev-ref", "HEAD"]) {
        data.branch = text;
    }

    if let Some(text) = run_git(
        path,
        &["rev-list", "--left-right", "--count", "HEAD...@{upstream}"],
    ) {
        let parts: Vec<&str> = text.split('\t').collect();
        if parts.len() == 2 {
            let ahead = parts[0].parse().unwrap_or(0);
            let behind = parts[1].parse().unwrap_or(0);
            data.ahead_behind = Some((ahead, behind));
        }
    }

    if let Some(text) = run_git(path, &["log", "-1", "--format=%h\t%s\t%ct"]) {
        let parts: Vec<&str> = text.splitn(3, '\t').collect();
        if parts.len() == 3 {
            let hash = parts[0].to_string();
            let message = parts[1].to_string();
            let epoch = parts[2].parse().unwrap_or(0);
            data.last_commit = Some((hash, message, epoch));
        }
    }

    if let Some(text) = run_git(path, &["diff", "--numstat"]) {
        let mut changes: Vec<(String, usize)> = text
            .lines()
            .filter_map(|line| {
                let parts: Vec<&str> = line.split('\t').collect();
                if parts.len() >= 3 {
                    let added: usize = parts[0].parse().unwrap_or(0);
                    let deleted: usize = parts[1].parse().unwrap_or(0);
                    let basename = parts[2].rsplit('/').next().unwrap_or(parts[2]);
                    Some((basename.to_string(), added + deleted))
                } else {
                    None
                }
            })
            .collect();
        changes.sort_by(|a, b| b.1.cmp(&a.1));
        data.file_changes = changes;
    }

    if let Some(text) = run_git(path, &["remote", "get-url", "origin"]) {
        data.remote_url = normalize_git_url(&text);
    }

    // Spawn `gh` with a timeout to avoid blocking the git thread indefinitely
    // (e.g. network issues, auth prompts).
    if let Ok(mut child) = Command::new("gh")
        .args(["pr", "view", "--json", "number", "-q", ".number"])
        .current_dir(path)
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::null())
        .stdin(std::process::Stdio::null())
        .spawn()
    {
        use std::time::{Duration, Instant};
        let deadline = Instant::now() + Duration::from_secs(5);
        loop {
            match child.try_wait() {
                Ok(Some(status)) => {
                    if status.success() {
                        if let Some(stdout) = child.stdout.take() {
                            use std::io::Read;
                            let mut buf = String::new();
                            let mut reader = stdout;
                            let _ = reader.read_to_string(&mut buf);
                            let num = buf.trim().to_string();
                            if !num.is_empty() {
                                data.pr_number = Some(num);
                            }
                        }
                    }
                    break;
                }
                Ok(None) => {
                    if Instant::now() >= deadline {
                        let _ = child.kill();
                        let _ = child.wait();
                        break;
                    }
                    std::thread::sleep(Duration::from_millis(100));
                }
                Err(_) => break,
            }
        }
    }

    data
}

pub(crate) fn run_git(path: &str, args: &[&str]) -> Option<String> {
    let mut cmd_args = vec!["-C", path];
    cmd_args.extend_from_slice(args);
    let output = Command::new("git").args(&cmd_args).output().ok()?;
    if output.status.success() {
        let s = String::from_utf8_lossy(&output.stdout).trim().to_string();
        if s.is_empty() { None } else { Some(s) }
    } else {
        None
    }
}

pub(crate) fn parse_diff_stat(text: &str) -> Option<(usize, usize)> {
    let text = text.trim();
    if text.is_empty() {
        return None;
    }
    let mut insertions = 0usize;
    let mut deletions = 0usize;
    for part in text.split(',') {
        let part = part.trim();
        if part.contains("insertion") {
            insertions = part
                .split_whitespace()
                .next()
                .and_then(|n| n.parse().ok())
                .unwrap_or(0);
        } else if part.contains("deletion") {
            deletions = part
                .split_whitespace()
                .next()
                .and_then(|n| n.parse().ok())
                .unwrap_or(0);
        }
    }
    Some((insertions, deletions))
}

pub(crate) fn normalize_git_url(url: &str) -> String {
    let url = url.trim();
    if let Some(rest) = url.strip_prefix("git@") {
        let converted = rest.replace(':', "/");
        let cleaned = converted.strip_suffix(".git").unwrap_or(&converted);
        format!("https://{cleaned}")
    } else if url.starts_with("https://") || url.starts_with("http://") {
        url.strip_suffix(".git").unwrap_or(url).to_string()
    } else {
        url.to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_diff_stat_both() {
        let result = parse_diff_stat("2 files changed, 4 insertions(+), 2 deletions(-)");
        assert_eq!(result, Some((4, 2)));
    }

    #[test]
    fn parse_diff_stat_insertions_only() {
        let result = parse_diff_stat("1 file changed, 5 insertions(+)");
        assert_eq!(result, Some((5, 0)));
    }

    #[test]
    fn parse_diff_stat_deletions_only() {
        let result = parse_diff_stat("1 file changed, 3 deletions(-)");
        assert_eq!(result, Some((0, 3)));
    }

    #[test]
    fn parse_diff_stat_empty() {
        assert_eq!(parse_diff_stat(""), None);
    }

    #[test]
    fn parse_diff_stat_whitespace() {
        assert_eq!(parse_diff_stat("   "), None);
    }

    #[test]
    fn normalize_git_url_ssh() {
        assert_eq!(
            normalize_git_url("git@github.com:user/repo.git"),
            "https://github.com/user/repo"
        );
    }

    #[test]
    fn normalize_git_url_https_with_git() {
        assert_eq!(
            normalize_git_url("https://github.com/user/repo.git"),
            "https://github.com/user/repo"
        );
    }

    #[test]
    fn normalize_git_url_https_clean() {
        assert_eq!(
            normalize_git_url("https://github.com/user/repo"),
            "https://github.com/user/repo"
        );
    }

    #[test]
    fn normalize_git_url_unknown_format() {
        assert_eq!(normalize_git_url("/local/path/repo"), "/local/path/repo");
    }
}
