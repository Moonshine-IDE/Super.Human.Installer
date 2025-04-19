; Inno Setup Script for Super.Human.Installer
; Equivalent to the NSIS script with better path handling

#define AppName GetEnv('PRODUCT_NAME')
#define AppVersion GetEnv('PRODUCT_VERSION')
#define AppPublisher GetEnv('PRODUCT_PUBLISHER')
#define AppURL GetEnv('PRODUCT_WEB_SITE')
#define BinPath GetEnv('BIN_PATH')
#define AppExeName GetEnv('PRODUCT_EXE')
#define OutputBaseFileName GetEnv('PRODUCT_INSTALLER')

[Setup]
AppId={{net.prominic.genesis.superhumaninstaller}}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
DefaultDirName={localappdata}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
LicenseFile=..\..\LICENSE.MD
OutputDir=.
OutputBaseFilename={#OutputBaseFileName}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
UsedUserAreasWarning=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Main application files
Source: "{#BinPath}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\{cm:ProgramOnTheWeb,{#AppName}}"; Filename: "{#AppURL}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{commondesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\App Paths\{#AppExeName}"; ValueType: string; ValueName: ""; ValueData: "{app}\{#AppExeName}"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\{#AppName}"; ValueType: string; ValueName: "DisplayName"; ValueData: "{#AppName}"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\{#AppName}"; ValueType: string; ValueName: "UninstallString"; ValueData: "{uninstallexe}"
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\{#AppName}"; ValueType: string; ValueName: "DisplayIcon"; ValueData: "{app}\{#AppExeName}"
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\{#AppName}"; ValueType: string; ValueName: "DisplayVersion"; ValueData: "{#AppVersion}"
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\{#AppName}"; ValueType: string; ValueName: "URLInfoAbout"; ValueData: "{#AppURL}"
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\{#AppName}"; ValueType: string; ValueName: "Publisher"; ValueData: "{#AppPublisher}"

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
procedure CurStepChanged(CurStep: TSetupStep);
var
  SourcePath, DestPath: string;
begin
  if CurStep = ssPostInstall then 
  begin
    // Copy provisioners to the common directory
    SourcePath := ExpandConstant('{app}\assets\provisioners\');
    DestPath := ExpandConstant('{localappdata}\{#AppName}\provisioners\');
    
    if DirExists(SourcePath) then
    begin
      if not DirExists(DestPath) then
        ForceDirectories(DestPath);
        
      Log('Copying provisioners from ' + SourcePath + ' to ' + DestPath);
      
      // Use built-in functions for copying files and directories
      DelTree(DestPath, True, True, True);
      CreateDir(DestPath);
      
      // Launch a cmd process with robocopy for better handling of long paths
      // Robocopy error codes 0-7 are considered successful
      Exec(ExpandConstant('{cmd}'), '/c robocopy "' + SourcePath + '" "' + DestPath + '" /E /R:1 /W:1 /NFL /NDL /NJH /NJS', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      
      if (ResultCode > 7) then
        Log('Robocopy failed with exit code: ' + IntToStr(ResultCode));
      else
        Log('Provisioners copied successfully');
    end;
  end;
end;
