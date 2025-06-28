Add-Type -AssemblyName System.Windows.Forms

#@p Select folder via dialog
$folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
$folderDialog.Description = "Select folder with audio files to analyze and normalize"

if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    $folderPath = $folderDialog.SelectedPath
    $outputDir = Join-Path $folderPath "optimized"

    if (!(Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir | Out-Null
    }

    #@p Supported extensions
    $extensions = @("*.wav", "*.mp3", "*.flac", "*.aac", "*.m4a")
    $files = $extensions | ForEach-Object { Get-ChildItem -Path $folderPath -Filter $_ }

    if ($files.Count -eq 0) {
        Write-Host "No supported audio files found in selected folder."
        Pause
        return
    }

    #@p Store analysis results
    $analysisResults = @()

    foreach ($file in $files) {
        $filePath = $file.FullName
        $fileName = $file.Name

        $ffmpegFirst = "ffmpeg -i `"$filePath`" -af loudnorm=I=-9:TP=-1.0:LRA=7:print_format=summary -f null -"
        $output = cmd /c $ffmpegFirst 2>&1

        $params = @{ I = ""; TP = ""; LRA = ""; thresh = ""; offset = "" }

        foreach ($line in $output) {
            if ($line -match "Input Integrated:\s+(-?[\d\.\,]+)") { $params.I = $matches[1] -replace ",","." }
            if ($line -match "Input True Peak:\s+(-?[\d\.\,]+)")   { $params.TP = $matches[1] -replace ",","." }
            if ($line -match "Input LRA:\s+(-?[\d\.\,]+)")         { $params.LRA = $matches[1] -replace ",","." }
            if ($line -match "Input Threshold:\s+(-?[\d\.\,]+)")   { $params.thresh = $matches[1] -replace ",","." }
            if ($line -match "Target Offset:\s+(-?[\d\.\,]+)")     { $params.offset = $matches[1] -replace ",","." }
        }

        $analysisResults += [PSCustomObject]@{
            Name     = $fileName
            Path     = $filePath
            I        = $params.I
            TP       = $params.TP
            LRA      = $params.LRA
            thresh   = $params.thresh
            offset   = $params.offset
        }
    }

    #@p Print analysis summary
    Write-Host "`n--- Loudness Analysis for all files ---"
    foreach ($entry in $analysisResults) {
        Write-Host "`nFile: $($entry.Name)"
        Write-Host "  Integrated Loudness: $($entry.I) LUFS"
        Write-Host "  True Peak:           $($entry.TP) dBTP"
        Write-Host "  Loudness Range:      $($entry.LRA) LU"
        Write-Host "  Threshold:           $($entry.thresh) LUFS"
        if ($entry.offset -ne "") {
            Write-Host "  Target Offset:       $($entry.offset) LU"
        } else {
            Write-Host "  Target Offset:       (not provided)"
        }
    }

    #@p Confirm normalization
    $confirm = Read-Host "`nNormalize all files listed above? (y/n)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Host "Aborted. No files were modified."
        Pause
        return
    }

    #@p Normalize all files with available data
    foreach ($entry in $analysisResults) {
        if ($entry.I -eq "" -or $entry.TP -eq "" -or $entry.LRA -eq "" -or $entry.thresh -eq "") {
            Write-Host "`nSkipping: $($entry.Name) - incomplete analysis data."
            continue
        }

        $outputPath = Join-Path $outputDir ([System.IO.Path]::GetFileNameWithoutExtension($entry.Name) + "_optimized" + [System.IO.Path]::GetExtension($entry.Name))

        if ($entry.offset -ne "") {
            $offsetParam = ":offset=$($entry.offset)"
        } else {
            $offsetParam = ""
        }

        $ffmpegSecond = @(
            "ffmpeg -y -i `"$($entry.Path)`" ",
            "-af loudnorm=I=-9:TP=-1.0:LRA=7",
            ":measured_I=$($entry.I)",
            ":measured_TP=$($entry.TP)",
            ":measured_LRA=$($entry.LRA)",
            ":measured_thresh=$($entry.thresh)",
            "$offsetParam",
            ":linear=true:print_format=summary ",
            "`"$outputPath`""
        ) -join ""

        cmd /c $ffmpegSecond

        Write-Host "`nNormalized: $($entry.Name)"
    }

    Write-Host "`nAll possible files have been normalized and saved to:"
    Write-Host "$outputDir"
} else {
    Write-Host "Cancelled: No folder selected."
}

Pause
