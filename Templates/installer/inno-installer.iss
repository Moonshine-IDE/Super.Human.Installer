; Inno Setup Script for Super.Human.Installer
; Using 7zip to handle long paths for provisioners

#define AppName GetEnv('PRODUCT_NAME')
#define AppVersion GetEnv('PRODUCT_VERSION')
#define AppPublisher GetEnv('PRODUCT_PUBLISHER')
#define AppURL GetEnv('PRODUCT_WEB_SITE')
#define BinPath GetEnv('BIN_PATH')
#define AppExeName GetEnv('PRODUCT_EXE')
#define OutputBaseFileName GetEnv('PRODUCT_INSTALLER')

[Setup]
AppId={{net.prominic.genesis.{#AppName}}}
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
PrivilegesRequiredOverridesAllowed=commandline
UsedUserAreasWarning=no
UninstallDisplayName={#AppName}
UninstallDisplayIcon={app}\{#AppExeName}
; Custom dark theme installer images
SetupIconFile=..\..\Assets\images\setup.ico
WizardSmallImageFile=..\..\Assets\images\wizard-small.bmp
WizardImageFile=..\..\Assets\images\wizard-large.bmp

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Main application files
Source: "{#BinPath}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; Compressed provisioners file
Source: "..\..\Assets\installer\provisioners.7z"; DestDir: "{tmp}"; Flags: ignoreversion deleteafterinstall

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\{cm:ProgramOnTheWeb,{#AppName}}"; Filename: "{#AppURL}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{commondesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Registry]
; Enable long paths in Windows
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\FileSystem"; ValueType: dword; ValueName: "LongPathsEnabled"; ValueData: "1"; Flags: noerror; Check: IsAdminInstallMode

; Application registry entries
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\App Paths\{#AppExeName}"; ValueType: string; ValueName: ""; ValueData: "{app}\{#AppExeName}"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\{#AppName}"; ValueType: string; ValueName: "UninstallString"; ValueData: "{uninstallexe}"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\{#AppName}"; ValueType: string; ValueName: "DisplayIcon"; ValueData: "{app}\{#AppExeName}"
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\{#AppName}"; ValueType: string; ValueName: "DisplayVersion"; ValueData: "{#AppVersion}"
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\{#AppName}"; ValueType: string; ValueName: "URLInfoAbout"; ValueData: "{#AppURL}"
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\{#AppName}"; ValueType: string; ValueName: "Publisher"; ValueData: "{#AppPublisher}"


[Run]
; Extract provisioners during installation
Filename: "{app}\assets\7za.exe"; Parameters: "x ""{tmp}\provisioners.7z"" -o""{userappdata}\{#AppName}\provisioners"" -y"; StatusMsg: "Extracting provisioners..."; Flags: runhidden

; Launch application after install
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// Custom dark theme colors
const
  DarkBackground = $1A1A1A;  // Dark background
  DarkText = $E0E0E0;        // Light text
  DarkAccent = $2D3046;      // Dark accent (slightly bluish)
  DarkControl = $2A2A2A;     // Dark control background

// Initialize dark theme for the entire installer
procedure InitializeWizard();
begin
  // Set colors for dark theme
  WizardForm.BackButton.Font.Color := clWhite;
  WizardForm.NextButton.Font.Color := clWhite;
  WizardForm.CancelButton.Font.Color := clWhite;
  WizardForm.BeveledLabel.Font.Color := clWhite;
  
  // Set text colors for labels
  WizardForm.WelcomeLabel1.Font.Color := clWhite;
  WizardForm.WelcomeLabel2.Font.Color := clWhite;
  WizardForm.FinishedLabel.Font.Color := clWhite;
  WizardForm.PageNameLabel.Font.Color := clWhite;
  WizardForm.PageDescriptionLabel.Font.Color := clWhite;
  
  // Use dark colors defined in SetupSkin.dll
  // The custom images already provide the dark theme appearance
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    // Clean up local and roaming app data directories
    DelTree(ExpandConstant('{localappdata}\{#AppName}'), True, True, True);
    DelTree(ExpandConstant('{userappdata}\{#AppName}'), True, True, True);
  end;
end;

[UninstallDelete]
; Clean up application directory
Type: filesandordirs; Name: "{localappdata}\{#AppName}"
; Clean up roaming app data
Type: filesandordirs; Name: "{userappdata}\{#AppName}"
