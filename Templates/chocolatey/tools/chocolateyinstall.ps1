$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$fileLocaction = Join-Path $toolsDir 'SuperHumanInstallerDev-Setup.exe'
$packageName = 'SuperHumanInstallerDev'

$packageArgs = @{
  packageName   = $packageName
  fileType      = 'EXE'
  file         	= $fileLocaction
  softwareName  = 'SuperHumanInstallerDev'

  # MSI
  silentArgs    = "/S" #NSIS
  validExitCodes= @(0, 3010, 1641)
}

Install-ChocolateyPackage @packageArgs
