# Advanced PowerShell Ping Monitor

[![License: CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-sa/4.0/)
[![PowerShell-Version](https://img.shields.io/badge/PowerShell-7.0%2B-blue.svg)](https://github.com/PowerShell/PowerShell)

An intelligent, aesthetic, and robust network latency monitor with automatic failover, designed for continuous, everyday use. This tool provides constant situational awareness of your network's stability with smart visual and harmonic audio feedback.

---

### ✨ Key Features

*   **🎯 Smart Failover:** Monitors a primary target (e.g., a game server). If it becomes unreachable, the script transparently switches to a stable fallback target (e.g., `8.8.8.8`) to monitor general internet connectivity.
*   **🔄 Automatic Recovery:** While on the fallback target, it periodically checks the primary target in the background. It automatically switches back as soon as the primary target is confirmed to be stable again.
*   **🔇 "Quiet Mode" for Outages:** After 10 consecutive packet losses, the script stops the repetitive error sounds and displays a clean, single-line status updating the current number of losses, preventing alert fatigue during a real outage.
*   **🔔 Harmonic Audio Alerts:** Uses a pleasant, harmonic musical scale for notifications:
    *   `E5` (659 Hz) for critical latency warnings.
    *   `D6` (1175 Hz) for packet loss errors.
    *   A C-Major arpeggio (`C6-E6-G6`) for a clear "Connection Restored!" notification.
*   **📊 Persistent Statistics:** Displays comprehensive session statistics (Total, Lost, Average, Loss Rate) every 10 successful pings, ensuring an accurate long-term view of your connection's quality.
*   **🎨 Aesthetic Interface:** Uses a customizable rainbow color cycle for successful pings to provide a visually pleasing and informative display.

---

### 🚀 Getting Started

#### Prerequisites
*   Windows 10 or 11
*   **PowerShell 7.0+** (Required for optimal color and syntax compatibility)

#### Installation
1.  Download the `advanced-ping-monitor.ps1` script to a convenient location on your computer (e.g., `C:\Scripts\`).
2.  Open a PowerShell 7 terminal.
3.  Navigate to the directory where you saved the script:
    ```powershell
    cd C:\Scripts\
    ```

---

### ⚙️ Usage

#### Basic Execution
To run the script with its default settings (monitoring a FFXIV server, fallback to Google DNS), simply execute it:

```powershell
.\advanced-ping-monitor.ps1
```

#### Custom Examples

*   **Monitor a different target and use a different fallback:**
    ```powershell
    .\advanced-ping-monitor.ps1 -PrimaryTarget "www.google.com" -FallbackTarget "1.1.1.1"
    ```

*   **Set a more aggressive latency threshold and mute all sounds:**
    ```powershell
    .\advanced-ping-monitor.ps1 -CriticalMs 75 -Mute
    ```

*   **Ping twice per second and increase the history size for the average calculation:**
    ```powershell
    .\advanced-ping-monitor.ps1 -IntervalMs 500 -HistorySize 60
    ```

---

### 🔧 Automatic Startup on Windows

To have the monitor launch automatically when you log into Windows, create a shortcut:

1.  Press `Win + R`, type `shell:startup`, and hit Enter. This will open your user's Startup folder.
2.  Right-click inside the folder and select `New` > `Shortcut`.
3.  In the "Type the location of the item" field, paste the following command. **Make sure to adjust the path to your script file!**

    ```
    "C:\Program Files\PowerShell\7\pwsh.exe" -NoLogo -ExecutionPolicy Bypass -File "C:\Scripts\advanced-ping-monitor.ps1"
    ```
4.  Click `Next`, give the shortcut a name (e.g., "Ping Monitor"), and click `Finish`.

---

### 📜 License

This project is licensed under the [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License](https://creativecommons.org/licenses/by-nc-sa/4.0/). See the `LICENSE` file for details.
