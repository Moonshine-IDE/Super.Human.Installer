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

// Function to apply dark theme to each wizard page
procedure DarkThemeWizardPage(Page: TWizardPage);
var
  I: Integer;
begin
  // Set dark background
  Page.Surface.Color := DarkBackground;
  
  // Update all controls in the page
  for I := 0 to Page.Surface.ControlCount - 1 do begin
    // Set text color for labels
    if Page.Surface.Controls[I] is TNewStaticText then begin
      TNewStaticText(Page.Surface.Controls[I]).Font.Color := DarkText;
    end;
    
    // Background for edit boxes and comboboxes
    if (Page.Surface.Controls[I] is TNewEdit) or 
       (Page.Surface.Controls[I] is TNewComboBox) then begin
      Page.Surface.Controls[I].Color := DarkControl;
      Page.Surface.Controls[I].Font.Color := DarkText;
    end;
    
    // Checkboxes and radio buttons
    if (Page.Surface.Controls[I] is TNewCheckBox) or 
       (Page.Surface.Controls[I] is TNewRadioButton) then begin
      TNewCheckListBox(Page.Surface.Controls[I]).Font.Color := DarkText;
    end;
  end;
end;

// Apply dark theme to each page when it's shown
procedure CurPageChanged(CurPageID: Integer);
begin
  DarkThemeWizardPage(WizardForm.Pages[WizardForm.CurPageID]);
end;

// Initialize dark theme for the entire installer
procedure InitializeWizard();
var
  I: Integer;
begin
  // Set the main form to dark mode
  WizardForm.Color := DarkBackground;
  
  // Set dark background for installer elements
  WizardForm.Bevel.Visible := False;  // Hide the bevel which shows light borders
  WizardForm.Bevel1.Visible := False;
  
  // Inner and outer pages
  WizardForm.InnerPage.Color := DarkBackground;
  WizardForm.OuterNotebook.Color := DarkBackground;
  
  // Set text colors
  WizardForm.PageNameLabel.Font.Color := DarkText;
  WizardForm.PageDescriptionLabel.Font.Color := DarkText;
  
  // Buttons
  WizardForm.BackButton.Font.Color := DarkText;
  WizardForm.NextButton.Font.Color := DarkText;
  WizardForm.CancelButton.Font.Color := DarkText;
  
  // Apply dark theme to all existing pages
  for I := 0 to WizardForm.PageCount - 1 do begin
    DarkThemeWizardPage(WizardForm.Pages[I]);
  end;
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
