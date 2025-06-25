# @p Hole das Verzeichnis, in dem das Skript liegt
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition

# @p Alle Dateien aus Unterordnern rekursiv finden (ausgeschlossen: Root)
$Files = Get-ChildItem -Path $ScriptRoot -Recurse -File | Where-Object {
    $_.DirectoryName -ne $ScriptRoot
}

foreach ($File in $Files) {
    $TargetPath = Join-Path -Path $ScriptRoot -ChildPath $File.Name

    # @p Falls Datei mit gleichem Namen schon existiert: umbenennen
    if (Test-Path $TargetPath) {
        $Base = [System.IO.Path]::GetFileNameWithoutExtension($File.Name)
        $Ext = [System.IO.Path]::GetExtension($File.Name)
        $Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $TargetPath = Join-Path $ScriptRoot "$Base-$Timestamp$Ext"
    }

    Write-Host "Kopiere: $($File.FullName) -> $TargetPath"
    Copy-Item -Path $File.FullName -Destination $TargetPath -Force
}

# @p Alle Unterordner löschen (rekursiv)
$SubFolders = Get-ChildItem -Path $ScriptRoot -Directory -Recurse | Sort-Object -Property FullName -Descending

foreach ($Folder in $SubFolders) {
    try {
        Remove-Item -Path $Folder.FullName -Recurse -Force
        Write-Host "Ordner gelöscht: $($Folder.FullName)"
    } catch {
        Write-Warning "Konnte Ordner nicht löschen: $($Folder.FullName)"
    }
}

Pause
