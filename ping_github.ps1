<#
.SYNOPSIS
    An aesthetic, persistent, and robust network latency monitor designed for daily use.

.DESCRIPTION
    This script is a monitoring tool that is both functional and decorative. It's designed
    to run continuously, providing situational awareness of network stability with immediate
    visual and audible feedback.

    At its core, it sends ICMP Ping requests to a specified target at a precise interval,
    managed by a high-precision clock for a steady rhythm. Each reply is displayed with a
    customizable color cycle. Alerts are handled distinctly: a critical latency is signaled
    in a bright color with a low-pitched beep, and a lost packet is highlighted on a full-line
    red background with a high-pitched beep. Comprehensive statistics are displayed every 10 pings.

    This version includes a smart startup routine that patiently waits for the network
    connection to be established before starting the monitoring, ensuring a reliable and
    error-free launch on Windows startup.

.PARAMETER Target
    The IP address or hostname of the target to monitor.
    Default: "1.1.1.1".

.PARAMETER IntervalMs
    The *target* interval between each ping dispatch, in milliseconds.
    Default: 1000.

.PARAMETER CriticalMs
    The latency threshold in milliseconds that triggers a visual and audible alert.
    Default: 150.

.PARAMETER HistorySize
    The number of results to keep for the moving average calculation.
    Default: 30.

.PARAMETER Mute
    If specified, disables all audible alerts.

.EXAMPLE
    PS C:\> .\advanced-ping-monitor.ps1

    Launches the script with default parameters, monitoring the IP "1.1.1.1".

.EXAMPLE
    PS C:\> .\advanced-ping-monitor.ps1 -Target "8.8.8.8" -CriticalMs 75 -Mute

    Monitors the IP "8.8.8.8", considers latency critical above 75 ms, and disables
    audible alerts.

.NOTES
    Version:      5.0
    Authors:      Gemini & Charles
    Date:         2025-08-17
    License:      CC BY-NC-SA 4.0

    Requires: PowerShell 7+ for optimal color and syntax compatibility.

    --------------------------- AUTOMATIC STARTUP ---------------------------
    For an automated launch on Windows startup, creating a shortcut in the
    'shell:startup' folder is recommended.

    Recommended shortcut target:
    "C:\Program Files\PowerShell\7\pwsh.exe" -NoLogo -ExecutionPolicy Bypass -File "C:\Full\Path\To\advanced-ping-monitor.ps1"

    COMPONENT DETAILS:
    - "...\pwsh.exe"      : Targets the PowerShell 7 executable. The full path
                          ensures the correct version is used.
    - -NoLogo             : Suppresses the startup banner for a clean display.
    - -ExecutionPolicy    : Bypasses the execution policy for this session only,
      Bypass                ensuring a reliable launch without altering system
                          security settings.
    - -File "...\ping.ps1": The instruction to execute the specified script file.
    -----------------------------------------------------------------------------

.LINK
    Get-Help about_Comment_Based_Help
#>

#Requires -Version 7.0
[CmdletBinding()]
Param(
    [string]$Target = "1.1.1.1",
    [int]$IntervalMs = 1000,
    [int]$CriticalMs = 150,
    [int]$HistorySize = 30,
    [switch]$Mute
)

# Global script configuration.
$script:Config = @{
    RainbowPalette = @(
        "Green", "DarkGreen", "Cyan", "DarkCyan", "Blue",
        "DarkBlue", "Magenta", "DarkMagenta", "Yellow", "DarkYellow"
    )
    ColorCritical  = "Red"
    ColorStats     = "White"
    ColorIndex     = 0
}

# Unified error types for clear ping failure handling.
enum PingFailureType {
    TimedOut
    HostUnreachable
    NetworkError
    Unknown
}

# Class encapsulating the details of a ping failure.
class PingFailure {
    [PingFailureType]$Type
    [string]$Message
    [string]$DisplayMessage
    
    PingFailure([PingFailureType]$type, [string]$message) {
        $this.Type = $type
        $this.Message = $message
        $this.DisplayMessage = switch ($type) {
            TimedOut { "Request timed out" }
            HostUnreachable { "Host unreachable" }
            NetworkError { "Network error" }
            default { "Unknown error" }
        }
    }
}

# Utility function to encapsulate the color cycling logic.
function Get-NextColor {
    $color = $script:Config.RainbowPalette[$script:Config.ColorIndex]
    $script:Config.ColorIndex = ($script:Config.ColorIndex + 1) % $script:Config.RainbowPalette.Count
    return $color
}

# Parses a ping reply or an exception to create a structured PingFailure object.
function Get-PingFailure {
    param(
        [System.Net.NetworkInformation.PingReply]$Reply,
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    
    if ($ErrorRecord) {
        $innerMessage = $ErrorRecord.Exception.InnerException?.Message ?? $ErrorRecord.Exception.Message
        return [PingFailure]::new([PingFailureType]::NetworkError, $innerMessage)
    }
    
    if ($Reply) {
        $type = switch ($Reply.Status) {
            'TimedOut' { [PingFailureType]::TimedOut }
            'DestinationHostUnreachable' { [PingFailureType]::HostUnreachable }
            'DestinationNetworkUnreachable' { [PingFailureType]::HostUnreachable }
            'DestinationPortUnreachable' { [PingFailureType]::HostUnreachable }
            'DestinationProhibited' { [PingFailureType]::HostUnreachable }
            default { [PingFailureType]::Unknown }
        }
        return [PingFailure]::new($type, $Reply.Status.ToString())
    }
    
    return [PingFailure]::new([PingFailureType]::Unknown, "Indeterminate error")
}

# Displays the formatted failure message and handles the audible alert.
function Show-PingFailure {
    param(
        [PingFailure]$Failure,
        [bool]$MuteBeep = $false
    )
    
    $width = $Host.UI.RawUI.WindowSize.Width
    $msg = "Reply from ${Target}: $($Failure.DisplayMessage)"
    
    if ($msg.Length -gt $width) {
        $msg = $msg.Substring(0, $width - 3) + "..."
    }
    
    $padding = " " * [Math]::Max(0, $width - $msg.Length)
    
    Write-Host "${msg}${padding}" -ForegroundColor White -BackgroundColor Red -NoNewline
    Write-Host "" # Resets terminal colors and adds the newline.

    if (-not $MuteBeep) { 
        [console]::Beep(1200, 200) 
    }
}

# Displays the formatted success message and handles the critical latency alert.
function Show-PingSuccess {
    param(
        [int]$Latency,
        [int]$TTL
    )
    
    $msg = "Reply from ${Target}: bytes=32 time=${Latency}ms TTL=${TTL}"
    
    if ($Latency -ge $CriticalMs) {
        Write-Host $msg -ForegroundColor $script:Config.ColorCritical
        if (-not $Mute) { 
            [console]::Beep(800, 300) 
        }
    }
    else {
        $color = Get-NextColor
        Write-Host $msg -ForegroundColor $color
    }
}

# Displays the calculated session statistics.
function Show-Statistics {
    param(
        [int]$Total,
        [int]$Lost,
        [System.Collections.Generic.Queue[int]]$History,
        [long]$HistorySum
    )
    
    $stats = [PSCustomObject]@{
        Total    = $Total
        Lost     = $Lost
        Average  = if ($History.Count) { [Math]::Round($HistorySum / $History.Count, 2) } else { "N/A" }
        LossRate = [Math]::Round(100 * $Lost / $Total, 2)
    }
    
    $statsLine = "Statistics: Total = $($stats.Total)  Lost = $($stats.Lost)  " +
    "Average = $($stats.Average)ms  Loss Rate = $($stats.LossRate)%"
    
    Write-Host $statsLine -ForegroundColor $script:Config.ColorStats
}

# Waits in a loop until a network connection is active before starting.
function Wait-NetworkConnection {
    param([System.Net.NetworkInformation.Ping]$Ping)
    
    Write-Host "Initializing ping monitor for '$Target'..." -ForegroundColor Yellow
    Write-Host "Waiting for a stable network connection..." -NoNewline
    
    while ($true) {
        try {
            $testPing = $Ping.Send($Target, 5000, ([byte[]](0..31)))
            if ($testPing.Status -eq 'Success') {
                Write-Host "`nConnection established! Starting monitor." -ForegroundColor Green
                Start-Sleep -Seconds 2
                return $true
            }
        }
        catch {
            # Silently ignore errors during the waiting phase.
        }
        
        Write-Host "." -ForegroundColor Yellow -NoNewline
        Start-Sleep -Seconds 2
    }
}

# === MAIN ENTRY POINT ===
try {
    # Initialize session objects and variables.
    $ping = [System.Net.NetworkInformation.Ping]::new()
    $payload = [byte[]](0..31)
    $history = [System.Collections.Generic.Queue[int]]::new()
    $historySum = 0L # Use a long type to prevent overflow.
    $stopwatch = [System.Diagnostics.Stopwatch]::new()
    $statistics = @{ Total = 0; Lost = 0 }
    
    Clear-Host
    
    # Wait for a working network connection before proceeding.
    $null = Wait-NetworkConnection -Ping $ping
    
    Clear-Host
    Write-Host "Pinging $Target with 32 bytes of data:" -ForegroundColor White
    Write-Host ""
    
    # Main monitoring loop.
    while ($true) {
        $stopwatch.Restart()
        $statistics.Total++
        
        try {
            $reply = $ping.Send($Target, $IntervalMs, $payload)
            
            if ($reply.Status -eq 'Success') {
                $latency = $reply.RoundtripTime
                $history.Enqueue($latency)
                $historySum += $latency
                $ttl = $reply.Options?.Ttl ?? 0
                Show-PingSuccess -Latency $latency -TTL $ttl
            }
            else {
                $statistics.Lost++
                $failure = Get-PingFailure -Reply $reply
                Show-PingFailure -Failure $failure -MuteBeep $Mute
            }
        }
        catch {
            $statistics.Lost++
            $failure = Get-PingFailure -ErrorRecord $_
            Show-PingFailure -Failure $failure -MuteBeep $Mute
        }
        
        # Maintain the history size by removing the oldest values.
        while ($history.Count -gt $HistorySize) {
            $historySum -= $history.Dequeue()
        }
        
        # Display statistics every 10 pings.
        if ($statistics.Total % 10 -eq 0 -and $statistics.Total -gt 0) {
            Show-Statistics -Total $statistics.Total -Lost $statistics.Lost -History $history -HistorySum $historySum
        }
        
        # Calculate the required pause to maintain the target interval.
        $stopwatch.Stop()
        $sleepDuration = $IntervalMs - $stopwatch.ElapsedMilliseconds
        if ($sleepDuration -gt 0) {
            Start-Sleep -Milliseconds $sleepDuration
        }
    }
}
finally {
    # Release allocated system resources.
    if ($ping) { 
        $ping.Dispose() 
    }
}