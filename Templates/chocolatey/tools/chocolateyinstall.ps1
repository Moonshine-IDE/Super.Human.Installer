﻿$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$fileLocaction = Join-Path $toolsDir 'SuperHumanInstaller-Setup.exe'
$packageName = 'SuperHumanInstaller'

$packageArgs = @{
  packageName   = $packageName
  fileType      = 'EXE'
  file         	= $fileLocaction
  softwareName  = 'SuperHumanInstaller'

  # MSI
  silentArgs    = "/S" #NSIS
  validExitCodes= @(0, 3010, 1641)
}

Install-ChocolateyPackage @packageArgs
