# @p Erlaubte Audioformate (alle klein, mit Punkt)
$AllowedExtensions = @(".m4a", ".wav", ".mp3", ".flac", ".aac", ".ogg", ".wma", ".aiff", ".alac", ".ps1")

# @p Basisordner = Ort des Skripts
$Root = Split-Path -Parent $MyInvocation.MyCommand.Definition

# @p Alle Dateien rekursiv finden
$AllFiles = Get-ChildItem -Path $Root -Recurse -File

foreach ($File in $AllFiles) {
    $Ext = $File.Extension.ToLower()

    if (-not ($AllowedExtensions -contains $Ext)) {
        try {
            Write-Host "Lösche: $($File.FullName)"
            Remove-Item -Path $File.FullName -Force
        } catch {
            Write-Warning "Konnte Datei nicht löschen: $($File.FullName)"
        }
    }
}
