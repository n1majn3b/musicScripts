Add-Type -AssemblyName System.Windows.Forms

Clear-Host
Write-Host ""
Write-Host "==== AUDIO NORMALISIEREN (CLUB-OPTIMIERT, AUTOMATISCH) ===="
Write-Host ""

# Datei auswaehlen
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.Filter = "WAV Dateien (*.wav)|*.wav"
$dialog.Title = "Waehle eine WAV-Datei"
if ($dialog.ShowDialog() -ne "OK") {
    Write-Host "Abgebrochen. Keine Datei ausgewaehlt."
    pause
    exit
}
$inputFile = $dialog.FileName
$directory = [System.IO.Path]::GetDirectoryName($inputFile)
$filename = [System.IO.Path]::GetFileNameWithoutExtension($inputFile)
$outputFile = Join-Path $directory ("normalized_" + $filename + ".wav")

# Ziel-Lautheit abfragen
Write-Host ""
Write-Host "Ziel-Lautheit eingeben (nur LUFS)."
Write-Host "Empfohlen fuer Club: -10"
$lufs = Read-Host "Ziel-Lautheit (LUFS)"
if ($lufs -eq "") { $lufs = "-10" }

# Sample Rate auslesen
Write-Host ""
Write-Host "Ermittle Sample Rate der Datei..."
$ffprobeCmd = "ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of default=noprint_wrappers=1:nokey=1 `"$inputFile`""
$sampleRate = & cmd /c $ffprobeCmd

if ($sampleRate -eq "") {
    Write-Host "Konnte Sample Rate nicht ermitteln. Abbruch."
    pause
    exit
}

# Befehl zusammenbauen
$cmd = "ffmpeg-normalize `"$inputFile`" -o `"$outputFile`" -nt ebu -t $lufs --dynamic --sample-rate $sampleRate -f"

# Zusammenfassung
Write-Host ""
Write-Host "Eingaben:"
Write-Host "Datei:         $filename.wav"
Write-Host "Ziel-Lautheit: $lufs LUFS"
Write-Host "Sample Rate:   $sampleRate Hz"
Write-Host "Modus:         Automatisch dynamisch (beste Qualitaet)"

# Bestätigung
$confirm = Read-Host "Normalisierung jetzt starten? (j/n)"
if ($confirm -ne "j") {
    Write-Host "Abgebrochen."
    pause
    exit
}

# Normalisierung starten
Write-Host ""
Write-Host "Starte Normalisierung..."
Write-Host $cmd
cmd.exe /c $cmd

Write-Host ""
Write-Host "Fertig. Normalisierte Datei gespeichert unter:"
Write-Host "$outputFile"
pause
