Add-Type -AssemblyName System.Windows.Forms

# Datei auswaehlen
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.Filter = "Audio Files|*.wav;*.mp3;*.flac"
$dialog.Title = "Select audio file"
$null = $dialog.ShowDialog()

if (-not $dialog.FileName) {
    Write-Host "No file selected. Exiting."
    exit
}

$InputFile = $dialog.FileName
$OutputFile = [System.IO.Path]::Combine(
    [System.IO.Path]::GetDirectoryName($InputFile),
    ([System.IO.Path]::GetFileNameWithoutExtension($InputFile) + "_clubready.wav")
)

# Analyse starten
Write-Host "`nRunning loudness analysis..."
$env:LC_ALL = "C"
$loudnormOutput = ffmpeg -hide_banner -i "$InputFile" -af "loudnorm=print_format=summary" -f null - 2>&1

# LUFS und TP extrahieren
$inputLUFS = ''
$inputTP = ''
foreach ($line in $loudnormOutput -split "`n") {
    if ($line -match "Input Integrated:\s*(-?[\d\.]+)") {
        $inputLUFS = [double]$matches[1]
    } elseif ($line -match "Input True Peak:\s*([+\-]?[\d\.]+)") {
        $inputTP = [double]$matches[1]
    }
}

if ($inputLUFS -eq '' -or $inputTP -eq '') {
    Write-Error "Could not extract loudness values."
    exit 1
}

Write-Host "Current LUFS: $inputLUFS"
Write-Host "Current True Peak: $inputTP dBTP"

# Zielwerte
$targetLUFS = -7.0
$maxTruePeak = -1.0

# Berechne maximal moeglichen Gain ohne Clipping
$headroom = $maxTruePeak - $inputTP  # z. B. -1.0 - 0.5 = -1.5 dB
$neededGain = $targetLUFS - $inputLUFS  # z. B. -7.0 - (-10.2) = +3.2 dB

$finalGain = [math]::Min($neededGain, $headroom)
$finalGain = [math]::Round($finalGain, 2)

if ($finalGain -le 0) {
    Write-Host "`nTrack is already loud or clipping. Applying no gain."
    Copy-Item $InputFile $OutputFile -Force
} else {
    Write-Host "`nApplying gain: +$finalGain dB"
    ffmpeg -y -i "$InputFile" -af "volume=${finalGain}dB" "$OutputFile"
}

# Abschlussanalyse
Write-Host "`nRe-analyzing result..."
$verify = ffmpeg -hide_banner -i "$OutputFile" -af "loudnorm=print_format=summary" -f null - 2>&1
$verify | Select-String "Input Integrated|Input True Peak" | Out-Host

Write-Host "`n✅ Done. Final file:"
Write-Host "$OutputFile"
