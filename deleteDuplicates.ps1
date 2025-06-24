# Setze das Arbeitsverzeichnis auf den Ordner des Skripts
$RootFolder = Get-Location

# Hashtable zur Erkennung von bereits gesehenen Dateinamen
$SeenNames = @{}

# Suche alle Dateien rekursiv im aktuellen Ordner
Get-ChildItem -Path $RootFolder -File -Recurse | ForEach-Object {
    $Name = $_.Name
    $FullPath = $_.FullName

    if ($SeenNames.ContainsKey($Name)) {
        Write-Host ("Duplicate found: {0} -> deleting {1}" -f $Name, $FullPath)
        Remove-Item -LiteralPath $FullPath -Force
    } else {
        $SeenNames[$Name] = $FullPath
    }
}
