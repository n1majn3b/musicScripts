Add-Type -AssemblyName System.Windows.Forms

#@p File selection dialog
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.Filter = "WAV files (*.wav)|*.wav"
$dialog.Multiselect = $false
$dialog.Title = "Select a WAV file for analysis and normalization"

if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    $filePath = $dialog.FileName
    $tempOut = "$env:TEMP\ffmpeg_output.txt"

    #@p Run ffmpeg loudness analysis
    $cmd = "ffmpeg -i `"$filePath`" -af loudnorm=I=-14:TP=-1.0:LRA=11:print_format=summary -f null - > `"$tempOut`" 2>&1"
    cmd /c $cmd

    #@p Extract relevant loudnorm lines
    $lines = Get-Content $tempOut
    $loudnessLines = $lines | Where-Object { $_ -match 'Input Integrated|Target Offset' }
    Write-Host "`n--- Loudness Analysis ---"
    $loudnessLines | ForEach-Object { Write-Host $_ }

    #@p Get numeric LUFS value
    $integratedLine = $loudnessLines | Where-Object { $_ -match 'Input Integrated' }
    $lufs = [double]($integratedLine -replace '[^\d\.\-]', '')

    #@p Threshold for Club-level normalization
    if ($lufs -lt -14) {
        $result = Read-Host "`nTrack is too quiet for club use (LUFS: $lufs). Normalize to -14 LUFS? (y/n)"
        if ($result -eq "y") {
            $outPath = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($filePath), "normalized_" + [System.IO.Path]::GetFileName($filePath))
            $normCmd = "ffmpeg -i `"$filePath`" -af loudnorm=I=-14:TP=-1.0:LRA=11 `"$outPath`""
            Write-Host "`nNormalizing..."
            cmd /c $normCmd
            Write-Host "Done. Saved to:`n$outPath"
        } else {
            Write-Host "Skipped normalization."
        }
    } else {
        Write-Host "`nTrack is already loud enough (LUFS: $lufs). No normalization needed."
    }
} else {
    Write-Host "No file selected."
}
