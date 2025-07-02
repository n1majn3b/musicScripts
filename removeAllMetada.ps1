# Remove all metadata from music files recursively, keeping only name and duration
# Preserves sample rate, codec, channels, and encoding
# Author: ZAB
# Version: 1.2
# Date: 2025-06-28

Add-Type -AssemblyName System.Windows.Forms

# Open folder selection dialog
$folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
$folderBrowser.Description = "Please select the folder containing your music files"
$folderBrowser.ShowNewFolderButton = $false

$dialogResult = $folderBrowser.ShowDialog()
if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "No folder selected. Exiting..."
    pause
    exit
}

$targetFolder = $folderBrowser.SelectedPath

# Define supported extensions
$audioExtensions = @("*.mp3", "*.flac", "*.wav", "*.aac", "*.ogg", "*.m4a")

# Create temporary working folder
$tempFolder = "$env:TEMP\CleanAudioTemp"
New-Item -ItemType Directory -Force -Path $tempFolder | Out-Null

# Get Shell COM object to read file properties
$shell = New-Object -ComObject Shell.Application

# Process each audio file
foreach ($ext in $audioExtensions) {
    Get-ChildItem -Path $targetFolder -Recurse -Include $ext | ForEach-Object {
        $file = $_
        $folder = Split-Path $file.FullName
        $shellFolder = $shell.Namespace($folder)
        $shellFile = $shellFolder.ParseName($file.Name)

        # Get original duration
        $duration = $shellFolder.GetDetailsOf($shellFile, 27)

        # Set new file path in temp folder
        $cleanedFile = Join-Path $tempFolder $file.Name

        # Remove metadata only, preserve all encoding properties
        ffmpeg -hide_banner -loglevel error -i "$($file.FullName)" -map_metadata -1 -c:a copy "$cleanedFile" -y

        # Overwrite original file
        Copy-Item -Path $cleanedFile -Destination $file.FullName -Force

        Write-Host "Cleaned: $($file.Name) | Duration: $duration"
    }
}

# Clean up temp folder
Remove-Item -Path $tempFolder -Recurse -Force

pause
