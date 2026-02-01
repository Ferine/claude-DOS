use std::process::{Command, Stdio};
use std::time::Duration;

/// QEMU test harness for claudeDOS
/// Launches QEMU with the floppy image and captures serial output.
pub struct QemuRunner {
    floppy_path: String,
    timeout: Duration,
}

impl QemuRunner {
    pub fn new(floppy_path: &str) -> Self {
        Self {
            floppy_path: floppy_path.to_string(),
            timeout: Duration::from_secs(10),
        }
    }

    pub fn with_timeout(mut self, timeout: Duration) -> Self {
        self.timeout = timeout;
        self
    }

    /// Boot the floppy in QEMU and capture serial output.
    /// Returns the captured output string.
    pub fn boot_and_capture(&self) -> Result<String, String> {
        let mut child = Command::new("qemu-system-i386")
            .args([
                "-fda",
                &self.floppy_path,
                "-boot",
                "a",
                "-m",
                "4",
                "-nographic",
                "-serial",
                "stdio",
                "-monitor",
                "none",
                "-no-reboot",
            ])
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .map_err(|e| format!("Failed to launch QEMU: {}", e))?;

        // Wait for timeout then kill
        std::thread::sleep(self.timeout);

        let _ = child.kill();
        let output = child
            .wait_with_output()
            .map_err(|e| format!("Failed to get QEMU output: {}", e))?;

        let stdout = String::from_utf8_lossy(&output.stdout).to_string();
        Ok(stdout)
    }

    /// Check if the boot output contains expected text
    pub fn expect_output(&self, expected: &str) -> Result<bool, String> {
        let output = self.boot_and_capture()?;
        Ok(output.contains(expected))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    #[ignore] // Run with: cargo test -- --ignored (requires QEMU)
    fn test_boot_to_banner() {
        let runner = QemuRunner::new("../images/floppy.img").with_timeout(Duration::from_secs(5));

        let output = runner.boot_and_capture().expect("QEMU should start");
        assert!(
            output.contains("claudeDOS"),
            "Boot output should contain 'claudeDOS', got: {}",
            output
        );
    }

    #[test]
    #[ignore]
    fn test_boot_shows_version() {
        let runner = QemuRunner::new("../images/floppy.img").with_timeout(Duration::from_secs(5));

        assert!(
            runner.expect_output("version 5.00").unwrap(),
            "Should show version 5.00"
        );
    }

    #[test]
    #[ignore]
    fn test_boot_reaches_prompt() {
        let runner = QemuRunner::new("../images/floppy.img").with_timeout(Duration::from_secs(8));

        let output = runner.boot_and_capture().expect("QEMU should start");
        assert!(
            output.contains("A:\\>") || output.contains("A:>"),
            "Should reach command prompt, got: {}",
            output
        );
    }
}
