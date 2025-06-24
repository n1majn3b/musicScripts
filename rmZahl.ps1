#@p Setze Arbeitsverzeichnis
$folderPath = "."
Set-Location -Path $folderPath

#@p Unterstützte Audioformate
$audioExtensions = @('.mp3', '.m4a', '.flac', '.wav', '.aac', '.ogg', '.wma', '.alac', '.aiff', '.opus')

#@p Durchsuche rekursiv alle Audiodateien
Get-ChildItem -File -Recurse | Where-Object {
    $audioExtensions -contains $_.Extension.ToLower()
} | ForEach-Object {
    $dir = $_.DirectoryName
    $baseName = $_.BaseName
    $extension = $_.Extension

    #@p Entferne z.B. "-1", "-2" am Ende des Dateinamens
    $newBaseName = $baseName -replace '-\d+$', ''

    $newName = "$newBaseName$extension"
    $newPath = Join-Path $dir $newName

    #@p Nur umbenennen, wenn sich der Name wirklich ändert und Ziel nicht bereits existiert
    if ($newName -ne $_.Name -and -not (Test-Path $newPath)) {
        Rename-Item -LiteralPath $_.FullName -NewName $newName
    }
}
