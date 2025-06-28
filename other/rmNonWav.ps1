<#
  SafeMoveNonWav.ps1
  Verschiebt rekursiv alle Dateien außer .wav und .ps1 aus dem aktuellen
  Verzeichnis und allen Unterverzeichnissen in den Ordner "NonWav",
  wobei die Ordnerstruktur erhalten bleibt. "NonWav" wird dabei ignoriert.
#>

$root = Get-Location
$destRoot = Join-Path $root "NonWav"

# Zielordner anlegen, wenn nicht vorhanden
if (-not (Test-Path $destRoot)) {
    New-Item -Path $destRoot -ItemType Directory | Out-Null
}

# Rekursive Durchsuchung aller Dateien
Get-ChildItem -Path $root -Recurse -File | Where-Object {
    # Nur verschieben, wenn:
    # - Datei-Endung NICHT .wav oder .ps1
    # - Datei NICHT bereits im Zielordner liegt
    ($_.Extension -notmatch '\.(wav|ps1)$') -and
    ($_.FullName -notlike "$destRoot*")
} | ForEach-Object {
    $sourcePath = $_.FullName
    $relativePath = $sourcePath.Substring($root.Path.Length).TrimStart('\')
    $targetPath = Join-Path $destRoot $relativePath
    $targetDir = Split-Path $targetPath

    # Zielordner anlegen, falls nötig
    if (-not (Test-Path $targetDir)) {
        New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
    }

    # Datei verschieben
    Move-Item -LiteralPath $sourcePath -Destination $targetPath -Force
    Write-Host "Moved: $relativePath"
}

Write-Host "Fertig. Alle Nicht-WAV- und Nicht-PS1-Dateien wurden rekursiv verschoben."
Pause