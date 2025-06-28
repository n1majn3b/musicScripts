Add-Type -AssemblyName System.Windows.Forms

$folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
$folderDialog.Description = "Select a folder with WAV files to normalize for club use"

if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    $folderPath = $folderDialog.SelectedPath
    $wavFiles = Get-ChildItem -Path $folderPath -Filter *.wav -File

    if ($wavFiles.Count -eq 0) {
        Write-Host "No WAV files found."
        Pause
        return
    }

    $targetLUFS = -6
    $tolerance = 2
    $minLUFS = $targetLUFS - $tolerance
    $maxLUFS = $targetLUFS + $tolerance
    $maxTP = -1.0
    $maxLRA = 9

    $tempOut = "$env:TEMP\ffmpeg_output.txt"
    $outputFolder = Join-Path $folderPath "normalizedForClub"
    if (-not (Test-Path $outputFolder)) {
        New-Item -Path $outputFolder -ItemType Directory | Out-Null
    }

    $filesToNormalize = @()

    foreach ($file in $wavFiles) {
        $cmd = "ffmpeg -hide_banner -i `"$($file.FullName)`" -af loudnorm=I=-14:TP=-1.0:LRA=11:print_format=summary -f null - > `"$tempOut`" 2>&1"
        cmd /c $cmd
        $lines = Get-Content $tempOut

        $data = @{LUFS = $null; TP = $null; LRA = $null}
        foreach ($line in $lines) {
            if ($line -match "Input Integrated:\s+(-?\d+(\.\d+)?) LUFS") {
                $data.LUFS = [double]$matches[1]
            } elseif ($line -match "Input True Peak:\s+(-?\d+(\.\d+)?) dBTP") {
                try { $data.TP = [double]$matches[1] } catch { $data.TP = $null }
            } elseif ($line -match "Input LRA:\s+(-?\d+(\.\d+)?) LU") {
                $data.LRA = [double]$matches[1]
            }
        }

        Write-Host "`n$file"
        Write-Host "  LUFS: $($data.LUFS) LUFS"
        Write-Host "  TP:   $($data.TP) dBTP"
        Write-Host "  LRA:  $($data.LRA) LU"

        if ($data.LUFS -eq $null -or $data.TP -eq $null) {
            Write-Host "  -> Could not read loudness values. Skipping."
            continue
        }

        $needsNorm = ($data.LUFS -lt $minLUFS -or $data.LUFS -gt $maxLUFS -or $data.TP -gt $maxTP -or $data.LRA -gt $maxLRA)
        if ($needsNorm) {
            $filesToNormalize += $file
        } else {
            Write-Host "  -> Already within club loudness standards."
        }
    }

    if ($filesToNormalize.Count -eq 0) {
        Write-Host "`nAll files meet the club loudness standard."
        Pause
        return
    }

    Write-Host "`nFiles to normalize:"
    $filesToNormalize | ForEach-Object { Write-Host " - $($_.Name)" }

    $confirm = Read-Host "`nNormalize ALL listed files to –6 LUFS, –1 dBTP, LRA 9? (y/n)"
    if ($confirm -ne "y") {
        Write-Host "Normalization cancelled."
        Pause
        return
    }

    foreach ($file in $filesToNormalize) {
        $outFile = Join-Path $outputFolder $file.Name
        $cmd = "ffmpeg -i `"$($file.FullName)`" -af loudnorm=I=$targetLUFS:TP=$maxTP:LRA=9 -map_metadata -1 `"$outFile`""
        Write-Host "`nNormalizing $($file.Name)..."
        cmd /c $cmd
        Write-Host "Saved: $outFile"
    }

    Write-Host "`nNormalization done. Files saved in: $outputFolder"
    Pause
} else {
    Write-Host "No folder selected."
    Pause
}
