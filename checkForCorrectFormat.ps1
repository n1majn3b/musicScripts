$musicDir = "."
$logFile = ".\FehlerhafteDateien.txt"
$desiredBitrate = 1411000
$desiredSampleRate = 44100
$desiredChannels = 2

# Leere Logdatei am Anfang
if (Test-Path $logFile) {
    Clear-Content -Path $logFile
}

# Unterstützte Audio-Formate
$extensions = @("*.wav", "*.flac", "*.aiff", "*.mp3", "*.m4a", "*.aac", "*.ogg", "*.wma")

foreach ($ext in $extensions) {
    Get-ChildItem -Path $musicDir -Recurse -Filter $ext | ForEach-Object {
        $file = $_.FullName

        # Ffprobe aufrufen und Key-Value-Ausgabe verwenden
        $info = & ffprobe -v error -select_streams a:0 -show_entries stream=bit_rate,sample_rate,channels -of default=noprint_wrappers=1 "$file"
        
        # Dictionary bauen
        $params = @{}
        foreach ($line in $info -split "`n") {
            if ($line -match "(.+?)=(.+)") {
                $params[$matches[1].Trim()] = $matches[2].Trim()
            }
        }

        $bitrate = [int]($params["bit_rate"] | ForEach-Object { $_ -as [int] })
        $samplerate = [int]($params["sample_rate"] | ForEach-Object { $_ -as [int] })
        $channels = [int]($params["channels"] | ForEach-Object { $_ -as [int] })

        # Nur wenn einer der Parameter abweicht
        if ($bitrate -ne $desiredBitrate -or $samplerate -ne $desiredSampleRate -or $channels -ne $desiredChannels) {
            "`n$file`n  Bitrate: $bitrate bps`n  SampleRate: $samplerate Hz`n  Channels: $channels" | Out-File -FilePath $logFile -Append
        }
    }
}

Pause
