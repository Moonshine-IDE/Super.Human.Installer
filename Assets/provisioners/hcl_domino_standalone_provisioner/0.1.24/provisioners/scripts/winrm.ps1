Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private
Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
winrm set winrm/config/service '@{AllowUnencrypted="true"}'