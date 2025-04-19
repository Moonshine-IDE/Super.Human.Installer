; Inno Setup Script for Super.Human.Installer
; Equivalent to the NSIS script with better path handling

#define AppName GetEnv('PRODUCT_NAME')
#define AppVersion GetEnv('PRODUCT_VERSION')
#define AppPublisher GetEnv('PRODUCT_PUBLISHER')
#define AppURL GetEnv('PRODUCT_WEB_SITE')
#define BinPath GetEnv('BIN_PATH')
#define AssetsPath GetEnv('ASSETS_PATH')
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
; Main application files - using exact path specified by BinPath
Source: "{#BinPath}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; Copy provisioners to the user's application data folder directly
Source: "{#AssetsPath}\provisioners\*"; DestDir: "{localappdata}\{#AppName}\provisioners"; Flags: ignoreversion recursesubdirs createallsubdirs

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
