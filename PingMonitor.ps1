# =============================================================================
# Ping Monitor Script
# Continuously pings configured addresses and logs results
# Press Ctrl+C to stop
# =============================================================================

# ===================== CONFIGURATION =====================
$Addresses = @(
    "8.8.8.8",
    "wp.pl",
    "google.com"
)

$ThresholdMs = 500          # Threshold for slow ping detection (milliseconds)
$PingDelaySeconds = 1       # Delay between ping cycles (seconds)
$StatsUpdateInterval = 10   # Update stats file every N pings per host

# Output files (current directory)
$RawFile = ".\raw.txt"
$StatsFile = ".\stats.txt"
$SlowFile = ".\slow.txt"

# ===================== INITIALIZATION =====================
# Initialize statistics tracking per host
$Stats = @{}
foreach ($addr in $Addresses) {
    $Stats[$addr] = @{
        Sent = 0
        Received = 0
        Lost = 0
        Times = [System.Collections.ArrayList]::new()
        Min = [double]::MaxValue
        Max = 0
        Sum = 0
    }
}

# Function to calculate jitter (average deviation between consecutive pings)
function Get-Jitter {
    param([System.Collections.ArrayList]$Times)
    
    if ($Times.Count -lt 2) { return 0 }
    
    $differences = @()
    for ($i = 1; $i -lt $Times.Count; $i++) {
        $differences += [Math]::Abs($Times[$i] - $Times[$i - 1])
    }
    
    if ($differences.Count -eq 0) { return 0 }
    return [Math]::Round(($differences | Measure-Object -Average).Average, 2)
}

# Function to format timestamp
function Get-Timestamp {
    return (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
}

# Function to write stats to file
function Write-Stats {
    $timestamp = Get-Timestamp
    $output = @()
    $output += "=" * 70
    $output += "PING STATISTICS - Updated: $timestamp"
    $output += "=" * 70
    
    foreach ($addr in $Addresses) {
        $s = $Stats[$addr]
        $lossPercent = if ($s.Sent -gt 0) { [Math]::Round(($s.Lost / $s.Sent) * 100, 2) } else { 0 }
        $avgTime = if ($s.Received -gt 0) { [Math]::Round($s.Sum / $s.Received, 2) } else { 0 }
        $minTime = if ($s.Min -eq [double]::MaxValue) { 0 } else { $s.Min }
        $jitter = Get-Jitter -Times $s.Times
        
        $output += ""
        $output += "Host: $addr"
        $output += "-" * 40
        $output += "  Packets Sent:     $($s.Sent)"
        $output += "  Packets Received: $($s.Received)"
        $output += "  Packets Lost:     $($s.Lost) ($lossPercent%)"
        $output += "  Min Latency:      $minTime ms"
        $output += "  Max Latency:      $($s.Max) ms"
        $output += "  Average Latency:  $avgTime ms"
        $output += "  Jitter:           $jitter ms"
    }
    
    $output += ""
    $output += ""
    
    $output -join "`r`n" | Out-File -FilePath $StatsFile -Append -Encoding UTF8
}

# ===================== MAIN LOOP =====================
Write-Host "Ping Monitor Started - Press Ctrl+C to stop" -ForegroundColor Green
Write-Host "Monitoring: $($Addresses -join ', ')" -ForegroundColor Cyan
Write-Host "Threshold: ${ThresholdMs}ms" -ForegroundColor Cyan
Write-Host "Output files: $RawFile, $StatsFile, $SlowFile" -ForegroundColor Cyan
Write-Host ""

$pingCount = 0

try {
    while ($true) {
        foreach ($addr in $Addresses) {
            $timestamp = Get-Timestamp
            $Stats[$addr].Sent++
            
            try {
                # Perform ping
                $ping = Test-Connection -ComputerName $addr -Count 1 -ErrorAction Stop
                
                # Extract response time (handle different PowerShell versions)
                if ($ping.ResponseTime) {
                    $responseTime = $ping.ResponseTime
                } elseif ($ping.Latency) {
                    $responseTime = $ping.Latency
                } else {
                    $responseTime = 0
                }
                
                # Update statistics
                $Stats[$addr].Received++
                $Stats[$addr].Sum += $responseTime
                $Stats[$addr].Times.Add($responseTime) | Out-Null
                
                # Keep only last 100 times for jitter calculation (memory management)
                if ($Stats[$addr].Times.Count -gt 100) {
                    $Stats[$addr].Times.RemoveAt(0)
                }
                
                if ($responseTime -lt $Stats[$addr].Min) { $Stats[$addr].Min = $responseTime }
                if ($responseTime -gt $Stats[$addr].Max) { $Stats[$addr].Max = $responseTime }
                
                # Raw output
                $rawLine = "[$timestamp] $addr - Reply: ${responseTime}ms"
                $rawLine | Out-File -FilePath $RawFile -Append -Encoding UTF8
                
                # Console output
                $color = if ($responseTime -gt $ThresholdMs) { "Yellow" } else { "White" }
                Write-Host $rawLine -ForegroundColor $color
                
                # Check threshold for slow pings
                if ($responseTime -gt $ThresholdMs) {
                    $slowLine = "[$timestamp] $addr - SLOW PING: ${responseTime}ms (threshold: ${ThresholdMs}ms)"
                    $slowLine | Out-File -FilePath $SlowFile -Append -Encoding UTF8
                    Write-Host "  ^ Logged to slow.txt" -ForegroundColor Red
                }
            }
            catch {
                # Ping failed (timeout or unreachable)
                $Stats[$addr].Lost++
                
                $rawLine = "[$timestamp] $addr - Request timed out / Host unreachable"
                $rawLine | Out-File -FilePath $RawFile -Append -Encoding UTF8
                Write-Host $rawLine -ForegroundColor Red
            }
        }
        
        $pingCount++
        
        # Update stats file periodically
        if ($pingCount % $StatsUpdateInterval -eq 0) {
            Write-Stats
            Write-Host "--- Stats updated ---" -ForegroundColor Magenta
        }
        
        # Wait before next cycle
        Start-Sleep -Seconds $PingDelaySeconds
    }
}
finally {
    # Write final stats on exit
    Write-Host "`nWriting final statistics..." -ForegroundColor Yellow
    Write-Stats
    Write-Host "Ping Monitor Stopped. Final stats saved." -ForegroundColor Green
}
