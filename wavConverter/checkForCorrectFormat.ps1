# Musikdateien analysieren und ggf. in optimales WAV-Format konvertieren
# Autor: ZAB
# Version: 1.2
# Datum: 2025-06-28

Add-Type -AssemblyName System.Windows.Forms

$desiredSampleRate = 44100
$desiredChannels = 2
$desiredFormat = ".wav"
$tempSuffix = "_converted_tmp.wav"

$checkedFiles = @{}

$folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
$folderBrowser.Description = "Bitte waehle den Ordner mit den Musikdateien aus"
$folderBrowser.ShowNewFolderButton = $false

$dialogResult = $folderBrowser.ShowDialog()
if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "Kein Ordner ausgewaehlt. Skript wird beendet."
    pause
    exit
}

$musicDir = $folderBrowser.SelectedPath

$extensions = @("*.wav", "*.flac", "*.aiff", "*.mp3", "*.m4a", "*.aac", "*.ogg", "*.wma")

function Ask-User {
    param([string]$message)
    $result = [System.Windows.Forms.MessageBox]::Show($message, "Konvertieren?", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    return $result -eq [System.Windows.Forms.DialogResult]::Yes
}

foreach ($ext in $extensions) {
    Get-ChildItem -Path $musicDir -Recurse -Filter $ext | ForEach-Object {
        $file = $_.FullName

        if ($checkedFiles.ContainsKey($file)) {
            return
        }

        $info = & ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate,channels -of default=noprint_wrappers=1 "$file"

        $params = @{ }
        foreach ($line in $info -split "`n") {
            if ($line -match "(.+?)=(.+)") {
                $params[$matches[1].Trim()] = $matches[2].Trim()
            }
        }

        $samplerate = [int]($params["sample_rate"] | ForEach-Object { $_ -as [int] })
        $channels = [int]($params["channels"] | ForEach-Object { $_ -as [int] })

        if ($samplerate -eq $desiredSampleRate -and $channels -eq $desiredChannels -and $file.ToLower().EndsWith($desiredFormat)) {
            $checkedFiles[$file] = $true
            return
        }

        $msg = "Abweichung gefunden:`n`nDatei: $file`nSampleRate: $samplerate Hz`nChannels: $channels`n`nIn optimales Format ($desiredSampleRate Hz, 16bit, 2ch, WAV) konvertieren?"
        if (Ask-User -message $msg) {
            $tempFile = $file + $tempSuffix

            ffmpeg -hide_banner -loglevel error -y -i "$file" -ar 44100 -ac 2 -sample_fmt s16 "$tempFile"

            if (Test-Path $tempFile) {
                Remove-Item -Path $file -Force
                Rename-Item -Path $tempFile -NewName (Split-Path -Leaf $file)
                Write-Host "Erfolgreich konvertiert: $file"
            } else {
                Write-Host "Konvertierung fehlgeschlagen: $file"
            }
        }

        $checkedFiles[$file] = $true
    }
}

pause
