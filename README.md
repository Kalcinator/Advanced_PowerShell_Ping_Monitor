# Advanced PowerShell Ping Monitor

An aesthetic, persistent, and robust network latency monitor designed for continuous, daily use in a modern PowerShell terminal.

![Script in action](URL_DE_VOTRE_IMAGE)

## About The Project

This script is a monitoring tool that is both functional and decorative. It's designed to run continuously, providing situational awareness of network stability with immediate visual and audible feedback. It sends ICMP Ping requests to a specified target at a precise interval and displays the results with clear, color-coded formatting and periodic statistics.

## Features

-   **Real-time Monitoring**: Pings a target at a steady, user-defined interval.
-   **High-Precision Timer**: Uses a `.NET Stopwatch` for accurate timing, ensuring the script sends a ping exactly every `N` milliseconds.
-   **Color-Coded Output**: Successful pings cycle through a rainbow palette for easy visual tracking. Critical latency and packet loss have distinct, high-visibility colors.
-   **Audible Alerts**: Provides optional, distinct beeps for high latency and packet loss.
-   **Periodic Statistics**: Displays session totals, packet loss count, loss rate, and a moving average latency every 10 pings.
-   **Smart Startup Routine**: Patiently waits for a stable network connection before starting, making it reliable for auto-launch on system startup.
-   **Robust Error Handling**: Gracefully handles network errors and different types of ping failures.

## Requirements

-   **PowerShell 7+**: Required for optimal color rendering and modern syntax compatibility.

## Usage

Save the script as `advanced-ping-monitor.ps1`. Run it from your PowerShell terminal.

#### **Default**

Launches the script with default parameters (pings 1.1.1.1 every second).

```powershell
.\advanced-ping-monitor.ps1
```

#### **Custom Parameters**

Monitors Google's DNS (`8.8.8.8`), considers latency critical above 75ms, and disables all sounds.

```powershell
.\advanced-ping-monitor.ps1 -Target "8.8.8.8" -CriticalMs 75 -Mute
```

### Script Parameters

| Parameter     | Description                                                                  | Default   |
| ------------- | ---------------------------------------------------------------------------- | --------- |
| `Target`      | The IP address or hostname of the target to monitor.                         | `1.1.1.1` |
| `IntervalMs`  | The target interval between each ping, in milliseconds.                      | `1000`    |
| `CriticalMs`  | The latency threshold (ms) that triggers a critical alert.                   | `150`     |
| `HistorySize` | The number of recent successful pings to use for the moving average.         | `30`      |
| `Mute`        | A switch parameter to disable all audible alerts.                            | `false`   |

---

## Auto-start on Windows

For an automated launch on Windows startup, creating a shortcut in the `shell:startup` folder is recommended.

1.  Press `Win + R` to open the Run dialog.
2.  Type `shell:startup` and press Enter. This will open the Startup folder.
3.  Right-click inside the folder, select `New` > `Shortcut`.
4.  In the "Type the location of the item" field, paste the following line (adjust the paths to match your system):

```
"C:\Program Files\PowerShell\7\pwsh.exe" -NoLogo -ExecutionPolicy Bypass -File "C:\Your\Path\To\advanced-ping-monitor.ps1"
```

5.  Click `Next`, give your shortcut a name (e.g., "Ping Monitor"), and click `Finish`.

The script will now launch automatically every time you log in to Windows.

## License

This project is licensed under the [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License](https://creativecommons.org/licenses/by-nc-sa/4.0/). See the `LICENSE` file for more details.
