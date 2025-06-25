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
    $outputFolder = Join-Path $folderPath "normalizedClubTracks"
    if (-not (Test-Path $outputFolder)) {
        New-Item -Path $outputFolder -ItemType Directory | Out-Null
    }

    Write-Host "`n--- Club Loudness Analysis ---"

    foreach ($file in $wavFiles) {
        #@p Run ffmpeg loudness analysis
        $cmd = "ffmpeg -hide_banner -i `"$($file.FullName)`" -af loudnorm=I=-14:TP=-1.0:LRA=11:print_format=summary -f null - > `"$tempOut`" 2>&1"
        cmd /c $cmd
        $lines = Get-Content $tempOut

        #@p Extract loudness data
        $data = @{
            LUFS = $null
            TP   = $null
            LRA  = $null
            THRESH = $null
        }

        foreach ($line in $lines) {
            if ($line -match "Input Integrated:\s+(-?\d+(\.\d+)?) LUFS") {
                $data.LUFS = [double]$matches[1]
            }
            elseif ($line -match "Input True Peak:\s+(-?\d+(\.\d+)?) dBTP") {
                $data.TP = [double]$matches[1]
            }
            elseif ($line -match "Input LRA:\s+(-?\d+(\.\d+)?) LU") {
                $data.LRA = [double]$matches[1]
            }
            elseif ($line -match "Input Threshold:\s+(-?\d+(\.\d+)?) LUFS") {
                $data.THRESH = [double]$matches[1]
            }
        }

        #@p Print results
        Write-Host "`n$file"
        Write-Host "  LUFS:     $($data.LUFS) LUFS"
        Write-Host "  TP:       $($data.TP) dBTP"
        Write-Host "  LRA:      $($data.LRA) LU"
        Write-Host "  Threshold:$($data.THRESH) LUFS"

        #@p Club standard checks with ±2 LUFS tolerance
        $minLUFS = -8
        $maxLUFS = -4

        $lufsOK = ($data.LUFS -ge $minLUFS -and $data.LUFS -le $maxLUFS)
        $tpOK   = ($data.TP -le -1.0)
        $lraOK  = ($data.LRA -le 11)

        if (-not $data.LUFS -or -not $data.TP) {
            Write-Host "  -> Could not extract full loudness data. Skipping normalization offer."
            continue
        }

        if ($lufsOK -and $tpOK -and $lraOK) {
            Write-Host "  -> Track is already optimized for club DJ use."
        } else {
            Write-Host "  -> This track is not fully optimized for club use."

            $answer = Read-Host "Normalize this track to Club DJ standard (-6 LUFS, TP -1.0 dBTP, LRA 9)? (y/n)"
            if ($answer -eq "y") {
                $outFile = Join-Path $outputFolder $file.Name

                #@p Normalize to club loudness level
                $normCmd = "ffmpeg -i `"$($file.FullName)`" -af loudnorm=I=-6:TP=-1.0:LRA=9 `"$outFile`""
                Write-Host "  Normalizing..."
                cmd /c $normCmd
                Write-Host "  Saved to: $outFile"
            } else {
                Write-Host "  -> Skipping normalization."
            }
        }
    }

    Write-Host "`nDone. Check 'normalizedClubTracks' folder if any tracks were processed."
    Pause
} else {
    Write-Host "No folder selected."
    Pause
}
