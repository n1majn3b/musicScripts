<#
  SafeMoveNonWav.ps1
  Verschiebt alle Dateien außer .wav und .ps1 aus dem aktuellen Verzeichnis
  (rekursiv), überspringt dabei den Zielordner "NonWav".
#>

$root = Get-Location
$destRoot = Join-Path $root "NonWav"

# Zielordner erstellen, falls nicht vorhanden
if (-not (Test-Path $destRoot)) {
    New-Item -Path $destRoot -ItemType Directory | Out-Null
}

# Dateien filtern: keine .wav, keine .ps1, kein Zielpfad
Get-ChildItem -Path $root -Recurse -File | Where-Object {
    $_.Extension -notmatch '\.(wav|ps1)$' -and
    ($_.FullName -notlike "$destRoot*")
} | ForEach-Object {
    # Relativer Pfad bezogen auf das Root-Verzeichnis
    $relativePath = $_.FullName.Substring($root.Path.Length).TrimStart('\')
    $targetPath = Join-Path $destRoot $relativePath
    $targetDir = Split-Path $targetPath

    # Zielordner anlegen falls nötig
    if (-not (Test-Path $targetDir)) {
        New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
    }

    # Datei verschieben
    Move-Item -LiteralPath $_.FullName -Destination $targetPath -Force
    Write-Host "Moved: $relativePath"
}

Write-Host "Fertig. Alle Nicht-WAV- und Nicht-PS1-Dateien wurden verschoben."
Pause
