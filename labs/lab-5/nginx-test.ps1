while ($true) {
    try {
        Invoke-WebRequest -Uri "http://localhost:8081" -UseBasicParsing | Out-Null
        Write-Output "Request sent successfully."
    } catch {
        Write-Output "Request failed: $_"
    }
    Start-Sleep -Seconds 1
}