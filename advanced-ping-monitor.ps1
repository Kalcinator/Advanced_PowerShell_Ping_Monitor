<#
.SYNOPSIS
    An intelligent, aesthetic, and robust network latency monitor with automatic failover and a real-time disconnection status.

.DESCRIPTION
    This script is an advanced connection monitoring tool, designed for continuous use.
    It provides situational awareness of network stability with smart visual and harmonic audio feedback.

    At its core, it sends ICMP Ping requests to a primary target. In case of failure,
    it transparently fails over to a stable fallback target (e.g., 8.8.8.8).

    While on the fallback target, the script periodically checks in the background if the primary target is
    reachable again. The switch back is only performed once the primary target is confirmed to be stable.

    Alert handling is finely tuned:
    - Critical Latency: Visual (bright color) and audio alert.
    - Packet Loss: Highlighted on a red background.
    - Prolonged Disconnection: After 10 consecutive failures, the script displays a single status line
      that updates in real-time with the number of losses for the current incident.

    Comprehensive and reliable statistics are displayed every 10 successful pings.

.PARAMETER PrimaryTarget
    The IP address or hostname of the primary target to monitor (e.g., a game server).
    Default: "80.239.145.6".

.PARAMETER FallbackTarget
    The IP address or hostname of the fallback target, used if the primary target is unreachable.
    Should be a highly stable target. Default: "8.8.8.8".

.PARAMETER IntervalMs
    The *target* interval between each ping request, in milliseconds. Default: 1000.

.PARAMETER CriticalMs
    The latency threshold in milliseconds that triggers a critical alert. Default: 175.

.PARAMETER HistorySize
    The number of results to keep for the average calculation. Default: 30.

.PARAMETER Mute
    If specified, disables all audio alerts.

.EXAMPLE
    PS C:\> .\advanced-ping-monitor.ps1

    Launches the script with default settings. It monitors the FFXIV server (80.239.145.6)
    and uses Google DNS (8.8.8.8) as its fallback target.

.EXAMPLE
    PS C:\> .\advanced-ping-monitor.ps1 -PrimaryTarget "www.google.com" -FallbackTarget "1.1.1.1"

    Monitors "www.google.com" as the primary target and uses Cloudflare DNS (1.1.1.1)
    in case of failure.

.NOTES
    Version:      7.6
    Authors:      Gemini & Charles
    Date:         2025-09-05
    License:      CC BY-NC-SA 4.0

    Requires: PowerShell 7+.

    --------------------------- AUTOMATIC STARTUP ---------------------------
    To launch this monitor automatically at Windows startup, it is recommended
    to create a shortcut in the user's startup folder.

    1. Press Win + R, type "shell:startup", and press Enter.
    2. In the folder that opens, right-click > New > Shortcut.
    3. In the "Type the location of the item" field, paste the following command:

    "C:\Program Files\PowerShell\7\pwsh.exe" -NoLogo -ExecutionPolicy Bypass -File "C:\Path\To\Your\advanced-ping-monitor.ps1"

    (Make sure to adjust the path to your advanced-ping-monitor.ps1 file if necessary)
    -----------------------------------------------------------------------------

.LINK
    Get-Help about_Comment_Based_Help
#>

#Requires -Version 7.0
[CmdletBinding()]
Param(
    [string]$PrimaryTarget = "80.239.145.6",
    [string]$FallbackTarget = "8.8.8.8",
    [int]$IntervalMs = 1000,
    [int]$CriticalMs = 175,
    [int]$HistorySize = 30,
    [switch]$Mute
)

$script:Config = @{
    RainbowPalette = @("Green", "DarkGreen", "Cyan", "DarkCyan", "Blue", "DarkBlue", "Magenta", "DarkMagenta", "Yellow", "DarkYellow")
    ColorCritical  = "Red"; ColorStats     = "White"; ColorIndex     = 0
}

# Unified error types for clear handling of ping failures.
enum PingFailureType {
    TimedOut
    HostUnreachable
    NetworkError
    Unknown
}

# Simplified class that acts as a data container for a ping failure.
class PingFailure {
    [PingFailureType]$Type
    [string]$OriginalStatus
    [string]$DisplayMessage
    
    PingFailure([PingFailureType]$type, [string]$originalStatus, [string]$displayMessage) {
        $this.Type = $type
        $this.OriginalStatus = $originalStatus
        $this.DisplayMessage = $displayMessage
    }
}

# --- UTILITY AND DISPLAY FUNCTIONS ---

function Get-NextColor {
    $color = $script:Config.RainbowPalette[$script:Config.ColorIndex]
    $script:Config.ColorIndex = ($script:Config.ColorIndex + 1) % $script:Config.RainbowPalette.Count
    return $color
}

# Parses a PingReply or ErrorRecord to create a structured and comprehensive PingFailure object.
function Get-PingFailure {
    [CmdletBinding(DefaultParameterSetName = 'FromReply')]
    param(
        [Parameter(ParameterSetName = 'FromReply')]
        [System.Net.NetworkInformation.PingReply]$Reply,

        [Parameter(ParameterSetName = 'FromError', Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,

        [Parameter(ParameterSetName = 'FromStatus', Mandatory = $true)]
        [System.Net.NetworkInformation.IPStatus]$Status
    )

    $resolveFromStatus = {
        param([System.Net.NetworkInformation.IPStatus]$statusValue)

        $status = $statusValue.ToString()
        $type = [PingFailureType]::Unknown
        $message = ""

        switch ($status) {
            'TimedOut' {
                $type = [PingFailureType]::TimedOut; $message = "Request timed out"
            }
            'DestinationHostUnreachable' {
                $type = [PingFailureType]::HostUnreachable; $message = "Destination host unreachable"
            }
            'DestinationNetworkUnreachable' {
                $type = [PingFailureType]::HostUnreachable; $message = "Destination network unreachable"
            }
            'DestinationProhibited' {
                $type = [PingFailureType]::HostUnreachable; $message = "Destination access prohibited (firewall)"
            }
            'DestinationPortUnreachable' {
                $type = [PingFailureType]::HostUnreachable; $message = "Destination port unreachable"
            }
            'BadDestination' {
                $type = [PingFailureType]::HostUnreachable; $message = "Invalid destination address"
            }
            'BadRoute' {
                $type = [PingFailureType]::NetworkError; $message = "Bad network route"
            }
            'TtlExpired' {
                $type = [PingFailureType]::NetworkError; $message = "Packet TTL (Time-To-Live) expired in transit"
            }
            'TtlReassemblyTimeExceeded' {
                $type = [PingFailureType]::NetworkError; $message = "Packet reassembly time (TTL) exceeded"
            }
            'PacketTooBig' {
                $type = [PingFailureType]::NetworkError; $message = "Packet too big (MTU issue)"
            }
            'BadOption' {
                $type = [PingFailureType]::NetworkError; $message = "Invalid packet option"
            }
            'ParameterProblem' {
                $type = [PingFailureType]::NetworkError; $message = "Parameter problem in IP header"
            }
            'BadHeader' {
                $type = [PingFailureType]::NetworkError; $message = "Invalid packet header"
            }
            'HardwareError' {
                $type = [PingFailureType]::NetworkError; $message = "Hardware error on the network"
            }
            'NoResources' {
                $type = [PingFailureType]::NetworkError; $message = "Insufficient system resources (local)"
            }
            'SourceQuench' {
                $type = [PingFailureType]::NetworkError; $message = "Network overload / Congestion"
            }
            'IcmpError' {
                $type = [PingFailureType]::NetworkError; $message = "ICMP protocol error"
            }
            default {
                $type = [PingFailureType]::Unknown; $message = "Unlisted error: $status"
            }
        }

        return [PingFailure]::new($type, $status, $message)
    }

    switch ($PSCmdlet.ParameterSetName) {
        'FromReply' {
            if ($null -ne $Reply) {
                return & $resolveFromStatus $Reply.Status
            }
        }
        'FromStatus' {
            return & $resolveFromStatus $Status
        }
        'FromError' {
            return [PingFailure]::new([PingFailureType]::NetworkError, "Exception", "Network error (Exception)")
        }
    }

    return [PingFailure]::new([PingFailureType]::Unknown, "NoReply", "Indeterminate error")
}

function Show-PingFailure {
    param([string]$DisplayTarget, [PingFailure]$Failure, [bool]$MuteBeep = $false)
    $width = $Host.UI.RawUI.WindowSize.Width; $msg = "Reply from ${DisplayTarget}: $($Failure.DisplayMessage)"
    $padding = " " * [Math]::Max(0, $width - $msg.Length)
    Write-Host "${msg}${padding}" -ForegroundColor White -BackgroundColor Red -NoNewline; Write-Host ""
    if (-not $MuteBeep) { [console]::Beep(1175, 200) }
}

function Update-QuietFailureStatus {
    param([int]$ConsecutiveCount)
    $msg = "🛑 Disconnected --- Current consecutive losses: $($ConsecutiveCount)"
    Write-Host "`r$msg" -ForegroundColor DarkYellow -NoNewline
}

function Show-PingSuccess {
    param([string]$DisplayTarget, [int]$Latency, [int]$TTL)
    Write-Host "`r" -NoNewline; $width = $Host.UI.RawUI.WindowSize.Width
    $msg = "Reply from ${DisplayTarget}: bytes=32 time=${Latency}ms TTL=${TTL}"
    $padding = " " * [Math]::Max(0, $width - $msg.Length)
    if ($Latency -ge $CriticalMs) {
        Write-Host ($msg + $padding) -ForegroundColor $script:Config.ColorCritical
        if (-not $Mute) { [console]::Beep(659, 300) }
    } else {
        Write-Host ($msg + $padding) -ForegroundColor (Get-NextColor)
    }
}

function Show-Statistics {
    param([int]$Total, [int]$Lost, [System.Collections.Generic.Queue[int]]$History, [long]$HistorySum)
    $stats = @{
        Total     = $Total; Lost      = $Lost
        Average   = if ($History.Count) { [Math]::Round($HistorySum / $History.Count, 2) } else { "N/A" }
        LossRate  = if ($Total -gt 0) { [Math]::Round(100 * $Lost / $Total, 2) } else { 0 }
    }
    $statsLine = "Statistics: Total = $($stats.Total)  Lost = $($stats.Lost)  Average = $($stats.Average)ms  Loss Rate = $($stats.LossRate)%"
    Write-Host $statsLine -ForegroundColor $script:Config.ColorStats
}

function Invoke-ReconnectionAlert {
    param([bool]$MuteBeep = $false)
    Write-Host "`n--- ✅ Connection restored! ---" -ForegroundColor Green
    if (-not $MuteBeep) {
        [console]::Beep(1047, 75); Start-Sleep -Milliseconds 50
        [console]::Beep(1319, 75); Start-Sleep -Milliseconds 50
        [console]::Beep(1568, 90)
    }
}

function Wait-NetworkConnection {
    param([hashtable]$State)
    Write-Host "Initializing... Testing primary target '$($State.PrimaryTarget)'..." -ForegroundColor Yellow
    foreach ($attempt in 1..3) {
        if ((Test-Connection -ComputerName $State.PrimaryTarget -Count 1 -Quiet -ErrorAction SilentlyContinue)) {
            $State.CurrentTarget = $State.PrimaryTarget
            Write-Host "Primary target is reachable. Starting monitor." -ForegroundColor Green; Start-Sleep 1; return
        }
        Write-Host "Attempt $attempt/3 failed..." -ForegroundColor DarkYellow; Start-Sleep 1
    }
    Write-Host "Primary target unreachable. Failing over to fallback target '$($State.FallbackTarget)'." -ForegroundColor Red
    $State.CurrentTarget = $State.FallbackTarget; $State.IsOnFallback = $true
    Write-Host "Waiting for a stable network connection..." -NoNewline
    while (-not (Test-Connection -ComputerName $State.FallbackTarget -Count 1 -Quiet -ErrorAction SilentlyContinue)) {
        Write-Host "." -ForegroundColor Yellow -NoNewline; Start-Sleep 2
    }
    Write-Host "`nConnection established via fallback target! Starting monitor." -ForegroundColor Green; Start-Sleep 2
}

# === MAIN ENTRY POINT ===
try {
    $ping = [System.Net.NetworkInformation.Ping]::new()
    $payload = [byte[]](0..31)
    $history = [System.Collections.Generic.Queue[int]]::new()
    $historySum = 0L
    $stopwatch = [System.Diagnostics.Stopwatch]::new()
    $statistics = @{ Total = 0; Lost = 0 }
    $state = @{
        PrimaryTarget        = $PrimaryTarget; FallbackTarget       = $FallbackTarget; CurrentTarget = $null
        IsOnFallback         = $false; ConsecutiveLosses    = 0; MaxConsecutiveLosses = 10; IsQuietMode = $false
        PrimaryCheckJob      = $null
    }
    
    Clear-Host; Wait-NetworkConnection -State $state
    Clear-Host; Write-Host "Sending 'Ping' requests to $($state.PrimaryTarget) (fallback: $($state.FallbackTarget)):" -ForegroundColor White; Write-Host ""
    
    while ($true) {
        $stopwatch.Restart(); $statistics.Total++
        $reply = $null
        
        if ($state.IsOnFallback) {
            if ($state.PrimaryCheckJob -and $state.PrimaryCheckJob.State -eq 'Completed') {
                $isPrimaryUp = Receive-Job -Job $state.PrimaryCheckJob
                Remove-Job -Job $state.PrimaryCheckJob
                $state.PrimaryCheckJob = $null

                if ($isPrimaryUp) {
                    Write-Host "`nPrimary target is reachable again. Switching back..." -ForegroundColor Green
                    $state.CurrentTarget = $state.PrimaryTarget; $state.IsOnFallback = $false
                    $history.Clear(); $historySum = 0L; Write-Host ""
                }
            }

            if (-not $state.PrimaryCheckJob) {
                $state.PrimaryCheckJob = Start-Job -ScriptBlock {
                    param($Target)
                    Test-Connection -ComputerName $Target -Count 1 -Quiet -ErrorAction SilentlyContinue
                } -ArgumentList $state.PrimaryTarget
            }
        }
        
        try {
            $reply = $ping.Send($state.CurrentTarget, $IntervalMs, $payload)
            if ($reply.Status -eq 'Success') {
                if ($state.IsQuietMode) { Invoke-ReconnectionAlert -MuteBeep $Mute }

                $state.IsQuietMode = $false; $state.ConsecutiveLosses = 0

                $latency = $reply.RoundtripTime; $history.Enqueue($latency); $historySum += $latency
                Show-PingSuccess -DisplayTarget $state.CurrentTarget -Latency $latency -TTL ($reply.Options?.Ttl ?? 0)
            } else { throw }
        } catch {
            $statistics.Lost++; $state.ConsecutiveLosses++
            if (-not $state.IsOnFallback -and $state.ConsecutiveLosses -eq 1) {
                Write-Host "`nPrimary target lost. Failing over to $($state.FallbackTarget)..." -ForegroundColor DarkYellow
                $state.IsOnFallback = $true; $state.CurrentTarget = $state.FallbackTarget; $history.Clear(); $historySum = 0L
            }
            if ($state.ConsecutiveLosses -ge $state.MaxConsecutiveLosses) { $state.IsQuietMode = $true }

            if ($state.IsQuietMode) {
                Update-QuietFailureStatus -ConsecutiveCount $state.ConsecutiveLosses
            } else {
                $failure = if ($null -ne $reply) { Get-PingFailure -Reply $reply } else { Get-PingFailure -ErrorRecord $_ }
                Show-PingFailure -DisplayTarget $state.CurrentTarget -Failure $failure -MuteBeep $Mute
            }
        }
        
        while ($history.Count -gt $HistorySize) { $historySum -= $history.Dequeue() }
        
        if (($statistics.Total % 10 -eq 0) -and ($state.ConsecutiveLosses -eq 0)) {
            Show-Statistics -Total $statistics.Total -Lost $statistics.Lost -History $history -HistorySum $historySum
        }
        
        $stopwatch.Stop()
        $sleepDuration = $IntervalMs - $stopwatch.ElapsedMilliseconds
        if ($sleepDuration -gt 0) { Start-Sleep -Milliseconds $sleepDuration }
    }
}
finally {
    if ($ping) { $ping.Dispose() }
    Get-Job | Remove-Job -Force
}
