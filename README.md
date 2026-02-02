# PowerShell Ping Monitor

A simple PowerShell script that continuously pings multiple hosts and logs latency, packet loss, and slow responses.

## Features

- Monitor multiple hosts simultaneously
- Track latency statistics (min/max/avg/jitter)
- Log slow pings above configurable threshold
- Calculate packet loss percentage
- Output to console and log files

## Usage

1. Open `PingMonitor.ps1` and configure the hosts to monitor:

```powershell
$Addresses = @(
    "8.8.8.8",
    "wp.pl",
    "google.com"
)
```

2. Adjust settings as needed:

```powershell
$ThresholdMs = 500          # Slow ping threshold (ms)
$PingDelaySeconds = 1       # Delay between ping cycles
$StatsUpdateInterval = 10   # Update stats every N pings
```

3. Run the script:

```powershell
.\PingMonitor.ps1
```

4. Press `Ctrl+C` to stop. Final statistics will be saved automatically.

## Output Files

| File | Description |
|------|-------------|
| `raw.txt` | All ping results with timestamps |
| `stats.txt` | Periodic statistics summary |
| `slow.txt` | Pings exceeding threshold |

## Sample Output

```
[2026-02-02 14:30:15.123] 8.8.8.8 - Reply: 12ms
[2026-02-02 14:30:15.456] google.com - Reply: 18ms
```

## Requirements

- Windows PowerShell 5.1+ or PowerShell Core 7+

## License

MIT
