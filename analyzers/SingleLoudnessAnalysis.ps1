Add-Type -AssemblyName System.Windows.Forms

#@p Select WAV file via dialog
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.Multiselect = $false
$dialog.Title = "Select a Audio file to analyze loudness"

if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    $filePath = $dialog.FileName
    $tempOut = "$env:TEMP\ffmpeg_output.txt"

    #@p Run FFmpeg via cmd and capture output
    $cmd = "ffmpeg -i `"$filePath`" -af loudnorm=I=-16:TP=-1.5:LRA=11:print_format=summary -f null - > `"$tempOut`" 2>&1"
    cmd /c $cmd

    #@p Extract only the relevant loudnorm data
    $lines = Get-Content $tempOut
    $loudnessLines = $lines | Where-Object { $_ -match 'Input|Output|Target Offset|Normalization Type' }

    Write-Host "`n--- Loudness Analysis ---"
    $loudnessLines | ForEach-Object { Write-Host $_ }
} else {
    Write-Host "No file selected."
}

Pause