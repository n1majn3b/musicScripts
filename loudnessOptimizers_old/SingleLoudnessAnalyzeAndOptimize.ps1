Add-Type -AssemblyName System.Windows.Forms

#@p Select audio file via dialog
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.Filter = "Audio files (*.wav;*.mp3;*.flac;*.aac;*.m4a)|*.wav;*.mp3;*.flac;*.aac;*.m4a"
$dialog.Title = "Select an audio file to analyze and normalize"
$dialog.Multiselect = $false

if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    $filePath = $dialog.FileName
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($filePath)
    $fileExt = [System.IO.Path]::GetExtension($filePath)
    $baseDir = [System.IO.Path]::GetDirectoryName($filePath)
    $outputDir = Join-Path $baseDir "optimized"
    $outputPath = Join-Path $outputDir "$fileName`_optimized$fileExt"

    if (!(Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir | Out-Null
    }

    #@p First pass: Analyze loudness
    $ffmpegFirst = "ffmpeg -i `"$filePath`" -af loudnorm=I=-9:TP=-1.0:LRA=7:print_format=summary -f null -"
    $output = cmd /c $ffmpegFirst 2>&1

    #@p Extract analysis values
    $params = @{ I = ""; TP = ""; LRA = ""; thresh = ""; offset = "" }

    foreach ($line in $output) {
        if ($line -match "Input Integrated:\s+(-?[\d\.\,]+)") { $params.I = $matches[1] -replace ",","." }
        if ($line -match "Input True Peak:\s+(-?[\d\.\,]+)")   { $params.TP = $matches[1] -replace ",","." }
        if ($line -match "Input LRA:\s+(-?[\d\.\,]+)")         { $params.LRA = $matches[1] -replace ",","." }
        if ($line -match "Input Threshold:\s+(-?[\d\.\,]+)")   { $params.thresh = $matches[1] -replace ",","." }
        if ($line -match "Target Offset:\s+(-?[\d\.\,]+)")     { $params.offset = $matches[1] -replace ",","." }
    }

    #@p Show results
    if ($params.I -eq "" -or $params.TP -eq "" -or $params.LRA -eq "" -or $params.thresh -eq "") {
        Write-Host "Error: Could not extract all required values from analysis."
    } else {
        Write-Host "`n--- Loudness Analysis ---"
        Write-Host "Integrated Loudness: $($params.I) LUFS"
        Write-Host "True Peak:           $($params.TP) dBTP"
        Write-Host "Loudness Range:      $($params.LRA) LU"
        Write-Host "Threshold:           $($params.thresh) LUFS"
        if ($params.offset -ne "") {
            Write-Host "Target Offset:       $($params.offset) LU"
        } else {
            Write-Host "Target Offset:       (not provided by ffmpeg)"
        }
        Write-Host "----------------------------------------"

        $confirm = Read-Host "Do you want to normalize this file? (y/n)"
        if ($confirm -eq 'y' -or $confirm -eq 'Y') {

            #@p Optional offset (only if present)
            if ($params.offset -ne "") {
                $offsetParam = ":offset=$($params.offset)"
            } else {
                $offsetParam = ""
            }

            #@p Second pass: Normalize with measured values
            $ffmpegSecond = @(
                "ffmpeg -y -i `"$filePath`" ",
                "-af loudnorm=I=-9:TP=-1.0:LRA=7",
                ":measured_I=$($params.I)",
                ":measured_TP=$($params.TP)",
                ":measured_LRA=$($params.LRA)",
                ":measured_thresh=$($params.thresh)",
                "$offsetParam",
                ":linear=true:print_format=summary ",
                "`"$outputPath`""
            ) -join ""

            cmd /c $ffmpegSecond

            Write-Host "`nFile successfully normalized:"
            Write-Host "$outputPath"
        } else {
            Write-Host "Aborted: No normalization performed."
        }
    }
} else {
    Write-Host "Cancelled: No file selected."
}

Pause
