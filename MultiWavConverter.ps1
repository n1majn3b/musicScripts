Add-Type -AssemblyName System.Windows.Forms

#@p Folder selection dialog
$folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
$folderDialog.Description = "Select a folder with audio files to convert for XDJ/CDJ"

if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    $folderPath = $folderDialog.SelectedPath

    #@p Get all audio files (by common extensions)
    $audioFiles = Get-ChildItem -Path $folderPath -File | Where-Object {
        $_.Extension -match '\.(wav|mp3|flac|m4a|aac|ogg|wma|aiff|alac)$'
    }

    if ($audioFiles.Count -eq 0) {
        Write-Host "No audio files found."
        Pause
        return
    }

    $outputFolder = Join-Path $folderPath "converted2WAV441"
    if (-not (Test-Path $outputFolder)) {
        New-Item -Path $outputFolder -ItemType Directory | Out-Null
    }

    $filesToConvert = @()

    foreach ($file in $audioFiles) {
        $ffprobeCmd = "ffprobe -v error -select_streams a:0 -show_entries stream=channels,sample_rate,codec_name -of default=nw=1 `"$($file.FullName)`""
        $ffprobeOutput = cmd /c $ffprobeCmd

        $info = @{Channels = $null; SampleRate = $null; Codec = ""}
        foreach ($line in $ffprobeOutput) {
            if ($line -match "^channels=(\d+)")       { $info.Channels = [int]$matches[1] }
            elseif ($line -match "^sample_rate=(\d+)"){ $info.SampleRate = [int]$matches[1] }
            elseif ($line -match "^codec_name=(\w+)") { $info.Codec = $matches[1] }
        }

        $formatOK = ($info.Channels -eq 2 -and $info.SampleRate -eq 44100 -and $info.Codec -eq "pcm_s16le" -and $file.Extension -eq ".wav")
        if (-not $formatOK) {
            $filesToConvert += $file
        }
    }

    if ($filesToConvert.Count -eq 0) {
        Write-Host "All files are already compatible with XDJ/CDJ format."
        Pause
        return
    }

    Write-Host "`nThe following files will be converted to WAV (44100 Hz, stereo, 16-bit, no metadata):"
    $filesToConvert | ForEach-Object { Write-Host " - $($_.Name)" }

    $confirm = Read-Host "`nConvert all listed files? (y/n)"
    if ($confirm -ne "y") {
        Write-Host "Conversion canceled."
        Pause
        return
    }

    foreach ($file in $filesToConvert) {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        $outFile = Join-Path $outputFolder "$baseName.wav"

        $cmd = "ffmpeg -i `"$($file.FullName)`" -ac 2 -ar 44100 -map_metadata -1 -c:a pcm_s16le `"$outFile`""
        Write-Host "`nConverting $($file.Name)..."
        cmd /c $cmd
        Write-Host "Saved: $outFile"
    }

    Write-Host "`nConversion complete. Files saved in: $outputFolder"
    Pause
} else {
    Write-Host "No folder selected."
    Pause
}
