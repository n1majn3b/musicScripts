Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Clear-Host
Write-Host ""
Write-Host "Starte Audio-Normalisierungswerkzeug"
Write-Host ""

# Datei auswaehlen
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.Filter = "Audio Files (*.wav;*.mp3)|*.wav;*.mp3"
$dialog.Title = "Waehle eine Audiodatei aus"
$dialog.Multiselect = $false
$dialog.ShowHelp = $false

$result = $dialog.ShowDialog()
if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "Keine Datei ausgewaehlt. Vorgang abgebrochen."
    pause
    exit
}

$inputFile = $dialog.FileName
$logFile = "$env:TEMP\loudnorm_log.txt"

# Alte Analyse loeschen
if (Test-Path $logFile) {
    Remove-Item $logFile -Force
}

# Analyse mit ffmpeg durchfuehren
Write-Host ""
Write-Host "Analysiere Datei..."
$analyseCmd = "ffmpeg -hide_banner -i `"$inputFile`" -af loudnorm=I=-14:TP=-1.0:LRA=11:print_format=json -f null - 2> `"$logFile`""
cmd.exe /c $analyseCmd

# Analysepruefung
if (-not (Test-Path $logFile)) {
    Write-Host "Fehler: Analyse fehlgeschlagen. Keine Daten vorhanden."
    pause
    exit
}

# Analysewerte extrahieren
$logText = Get-Content -Path $logFile -Raw

function Get-Value($key) {
    $lines = $logText -split "`n"
    foreach ($line in $lines) {
        if ($line -like "*$key*") {
            $clean = $line -replace '"', ''
            $parts = $clean.Split(":")
            if ($parts.Count -eq 2) {
                return $parts[1].Trim().TrimEnd(',')
            }
        }
    }
    return ""
}

$I       = Get-Value "input_i"
$TP      = Get-Value "input_tp"
$LRA     = Get-Value "input_lra"
$THRESH  = Get-Value "input_thresh"
$OFFSET  = Get-Value "target_offset"

# Ausgabe der Analysewerte
Write-Host ""
Write-Host "Analyseergebnisse:"
Write-Host "Lautheit (LUFS):        $I     -> gemessene Durchschnittslautheit des Audios (Ziel z. B. -14)"
Write-Host "True Peak (dB):         $TP    -> hoechste digitale Spitze im Signal (sicher unter -1.0 halten)"
Write-Host "Dynamikbereich (LU):    $LRA   -> Unterschied zwischen laut und leise, gut sind 8 bis 11"
Write-Host "Threshold:              $THRESH -> Lautstaerke-Grenze, ab der ffmpeg das Signal beachtet"
Write-Host "Offset:                 $OFFSET -> Korrekturwert, um die Lautheit auf das Ziel anzugleichen"

if ([string]::IsNullOrWhiteSpace($I) -or
    [string]::IsNullOrWhiteSpace($TP) -or
    [string]::IsNullOrWhiteSpace($LRA) -or
    [string]::IsNullOrWhiteSpace($THRESH) -or
    [string]::IsNullOrWhiteSpace($OFFSET)) {
    Write-Host ""
    Write-Host "Fehler: Analysewerte unvollstaendig. Vorgang abgebrochen."
    pause
    exit
}

Write-Host ""
Write-Host "Zielwerte waehlen - Empfehlungen basieren auf Analysewerten (nichts eingebn und enter drücken für empfohlene Werte)"

$targetI = Read-Host "Ziel-Lautheit in LUFS (empfohlen -14, Original: $I)"
if ($targetI -eq "") { $targetI = "-14" }

$targetTP = Read-Host "Ziel-True-Peak (empfohlen -1.0, Original: $TP)"
if ($targetTP -eq "") { $targetTP = "-1.0" }

$targetLRA = Read-Host "Ziel-Dynamikbereich in LU (empfohlen 11, Original: $LRA)"
if ($targetLRA -eq "") { $targetLRA = "11" }

$targetTHRESH = Read-Host "Schwellenwert (Threshold) in dB (empfohlen $THRESH)"
if ($targetTHRESH -eq "") { $targetTHRESH = $THRESH }

$targetOFFSET = Read-Host "Offset zur Lautheitskorrektur (empfohlen $OFFSET)"
if ($targetOFFSET -eq "") { $targetOFFSET = $OFFSET }

# Bestaetigung
$antwort = Read-Host "Normalisierung starten? (j/n)"
if ($antwort -ne "j") {
    Write-Host "Normalisierung abgebrochen."
    pause
    exit
}

# Zielpfad definieren
$directory = [System.IO.Path]::GetDirectoryName($inputFile)
$filename = [System.IO.Path]::GetFileName($inputFile)
$outputFile = Join-Path $directory ("normalized_" + $filename)

# Normalisierung ausfuehren
Write-Host ""
Write-Host "Starte Normalisierung..."

$normCmd = "ffmpeg -i `"$inputFile`" -af loudnorm=I=${targetI}:TP=${targetTP}:LRA=${targetLRA}:" +
           "measured_I=${I}:measured_TP=${TP}:measured_LRA=${LRA}:" +
           "measured_thresh=${targetTHRESH}:offset=${targetOFFSET}:linear=1:print_format=summary " +
           "-ar 44100 -ac 2 -sample_fmt s16 `"$outputFile`""

Write-Host $normCmd
cmd.exe /c $normCmd

# Abschlussmeldung
Write-Host ""
Write-Host "Normalisierung abgeschlossen."
Write-Host "Datei gespeichert unter:"
Write-Host "$outputFile"

pause
