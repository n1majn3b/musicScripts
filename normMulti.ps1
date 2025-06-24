Add-Type -AssemblyName System.Windows.Forms

#@p Folder selection dialog
$folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
$folderDialog.Description = "Select a folder with WAV files for analysis and normalization"

if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    $folderPath = $folderDialog.SelectedPath
    $wavFiles = Get-ChildItem -Path $folderPath -Filter *.wav -File

    if ($wavFiles.Count -eq 0) {
        Write-Host "No WAV files found in the selected folder."
        Pause
        return
    }

    $tempOut = "$env:TEMP\ffmpeg_output.txt"
    $toNormalize = @()

    Write-Host "`n--- Loudness Analysis ---"

    foreach ($file in $wavFiles) {
        #@p Run ffmpeg loudness analysis per file
        $cmd = "ffmpeg -hide_banner -i `"$($file.FullName)`" -af loudnorm=I=-14:TP=-1.0:LRA=11:print_format=summary -f null - > `"$tempOut`" 2>&1"
        cmd /c $cmd

        $lines = Get-Content $tempOut
        $matchLine = $lines | Where-Object { $_ -match 'Input Integrated' }

        if (-not $matchLine) {
            Write-Host "$($file.Name):  [No 'Input Integrated' line found]"
            Write-Host "Excerpt from ffmpeg output:"
            $lines | Select-String 'loudnorm|LUFS|Integrated' | ForEach-Object { Write-Host "  $_" }
            continue
        }

        $lufsRaw = $matchLine -replace '[^\-0-9\.]', '' | Select-Object -First 1

        try {
            $lufs = [double]$lufsRaw
            $diff = [math]::Round($lufs + 14, 2)
            if ($diff -gt 0) {
                Write-Host "$($file.Name): $lufs LUFS ($diff dB too quiet)"
                $toNormalize += [PSCustomObject]@{
                    File = $file
                    LUFS = $lufs
                    Diff = $diff
                }
            } else {
                Write-Host "$($file.Name): $lufs LUFS (OK)"
            }
        } catch {
            Write-Host "$($file.Name):  [Could not convert LUFS: '$lufsRaw']"
            Write-Host "Excerpt from ffmpeg output:"
            $lines | Select-String 'loudnorm|LUFS|Integrated' | ForEach-Object { Write-Host "  $_" }
        }
    }

    if ($toNormalize.Count -eq 0) {
        Write-Host "`nAll tracks are loud enough. No normalization needed."
        Pause
        return
    }

    Write-Host "`nThe following files are below -14 LUFS and will be normalized:"
    $toNormalize | ForEach-Object { Write-Host "$($_.File.Name): $($_.LUFS) LUFS ($($_.Diff) dB too quiet)" }

    $confirm = Read-Host "`nNormalize all listed files to -14 LUFS? (y/n)"
    if ($confirm -ne "y") {
        Write-Host "Normalization canceled."
        Pause
        return
    }

    $outputFolder = Join-Path $folderPath "normalizedAudioFiles"
    if (-not (Test-Path $outputFolder)) {
        New-Item -Path $outputFolder -ItemType Directory | Out-Null
    }

    foreach ($entry in $toNormalize) {
        $inFile = $entry.File.FullName
        $outFile = Join-Path $outputFolder $entry.File.Name
        $normCmd = "ffmpeg -i `"$inFile`" -af loudnorm=I=-14:TP=-1.0:LRA=11 `"$outFile`""
        Write-Host "`nNormalizing $($entry.File.Name)..."
        cmd /c $normCmd
        Write-Host "Saved to: $outFile"
    }

    Write-Host "`nAll selected files normalized and saved in:`n$outputFolder"
    Pause
} else {
    Write-Host "No folder selected."
    Pause
}
