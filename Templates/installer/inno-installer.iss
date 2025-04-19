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
; Custom dark theme installer images and skin
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

; Add the ISSkin DLL used for skinning Inno Setup installations
Source: "ISSkin.dll"; DestDir: "{tmp}"; Flags: dontcopy

; Add the Visual Style resource
Source: "Vista.cjstyles"; DestDir: "{tmp}"; Flags: dontcopy

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
Filename: "{app}\assets\bin\7za.exe"; Parameters: "x ""{tmp}\provisioners.7z"" -o""{userappdata}\{#AppName}\provisioners"" -y"; StatusMsg: "Extracting provisioners..."; Flags: runhidden
; Clean up the 7z file after extraction
Filename: "cmd.exe"; Parameters: "/c del ""{userappdata}\{#AppName}\provisioners.7z"""; StatusMsg: "Cleaning up temporary files..."; Flags: runhidden

; Launch application after install
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent


[Code]
// Importing LoadSkin API from ISSkin.DLL
procedure LoadSkin(lpszPath: String; lpszIniFileName: String);
external 'LoadSkin@files:isskin.dll stdcall';

// Importing UnloadSkin API from ISSkin.DLL
procedure UnloadSkin();
external 'UnloadSkin@files:isskin.dll stdcall';

// Importing ShowWindow Windows API from User32.DLL
function ShowWindow(hWnd: Integer; uType: Integer): Integer;
external 'ShowWindow@user32.dll stdcall';

// Windows API functions for extended path handling
function RemoveDirectoryW(lpPathName: String): Boolean;
external 'RemoveDirectoryW@kernel32.dll stdcall';

function DeleteFileW(lpFileName: String): Boolean;
external 'DeleteFileW@kernel32.dll stdcall';

function FindFirstFileW(lpFileName: String; var lpFindFileData: TFindRec): THandle;
external 'FindFirstFileW@kernel32.dll stdcall';

function FindNextFileW(hFindFile: THandle; var lpFindFileData: TFindRec): Boolean;
external 'FindNextFileW@kernel32.dll stdcall';

function FindClose(hFindFile: THandle): Boolean;
external 'FindClose@kernel32.dll stdcall';

function InitializeSetup(): Boolean;
begin
  ExtractTemporaryFile('Vista.cjstyles');
  LoadSkin(ExpandConstant('{tmp}\Vista.cjstyles'), 'NormalBlack.ini');
  Result := True;
end;

procedure DeinitializeSetup();
begin
  // Hide Window before unloading skin so user does not get
  // a glimpse of an unskinned window before it is closed
  ShowWindow(StrToInt(ExpandConstant('{wizardhwnd}')), 0);
  UnloadSkin();
end;

// Create a batch file for deletion and execute it
procedure CreateAndExecuteCleanupBatch(DirPath: string);
var
  BatFileName, BatFilePath: string;
  ResultCode: Integer;
  RetryCount: Integer;
  RetryResult: Integer;
begin
  // Create a temporary batch file in the temp directory
  BatFileName := 'cleanup_' + ExtractFileName(DirPath) + '.bat';
  BatFilePath := ExpandConstant('{tmp}\' + BatFileName);
  
  // Write the batch file with commands to delete the directories
  SaveStringToFile(BatFilePath, 
    '@echo off' + #13#10 +
    'echo Cleaning up application files and directories...' + #13#10 +
    'echo This may take a while for directories with long paths.' + #13#10 +
    'echo.' + #13#10 +
    // Use robocopy to empty the directory first (often better with locked files)
    'if exist "' + DirPath + '" (' + #13#10 +
    '  mkdir "%TEMP%\empty_dir"' + #13#10 +
    '  robocopy "%TEMP%\empty_dir" "' + DirPath + '" /MIR /NFL /NDL /NJH /NJS /nc /ns /np' + #13#10 +
    '  rmdir "%TEMP%\empty_dir"' + #13#10 +
    ')' + #13#10 +
    // Then use RD to fully remove it, with /S for recursive deletion and /Q for quiet mode
    'rd /s /q "' + DirPath + '" 2>nul' + #13#10 +
    // If that fails, try with the long path prefix
    'if exist "' + DirPath + '" (' + #13#10 +
    '  rd /s /q "\\?\' + DirPath + '" 2>nul' + #13#10 +
    ')' + #13#10 +
    'exit 0' + #13#10, 
    False
  );
  
  RetryCount := 0;
  repeat
    // Execute the batch file
    if Exec('cmd.exe', '/c "' + BatFilePath + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    begin
      // Check if directory still exists
      if DirExists(DirPath) and (RetryCount < 3) then
      begin
        RetryResult := MsgBox('Some files in ' + DirPath + ' could not be deleted. They may be in use by another program.' + #13#10#13#10 + 
                            'Retry the operation?', mbError, MB_RETRYCANCEL);
        if RetryResult = IDRETRY then
        begin
          Inc(RetryCount);
          Sleep(1000); // Give it a second before retrying
          continue;
        end
        else
          break;
      end
      else
        break;
    end
    else
      break;
  until False;
  
  // Clean up the batch file
  DeleteFile(BatFilePath);
end;

// Handle uninstallation process
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  AppLocalPath, AppRoamingPath, ProvisionersPath: string;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    // IMPORTANT: These paths only target the application's own directories
    // They will NOT affect any other user data
    AppLocalPath := ExpandConstant('{localappdata}\{#AppName}');
    AppRoamingPath := ExpandConstant('{userappdata}\{#AppName}');
    ProvisionersPath := AppRoamingPath + '\provisioners';
    
    // Log what we're trying to remove
    Log('Cleaning up application directory: ' + AppLocalPath);
    Log('Cleaning up application data in roaming: ' + AppRoamingPath);
    
    // First try to clean up the provisioners directory (most likely to have long paths)
    if DirExists(ProvisionersPath) then
    begin
      Log('Attempting to remove provisioners using batch script: ' + ProvisionersPath);
      CreateAndExecuteCleanupBatch(ProvisionersPath);
    end;
    
    // Now try batch cleanup for the main directories too
    CreateAndExecuteCleanupBatch(AppLocalPath);
    CreateAndExecuteCleanupBatch(AppRoamingPath);
  end;
end;

[UninstallDelete]
; Clean up application directory in local AppData
Type: filesandordirs; Name: "{localappdata}\{#AppName}"

; Clean up application directory in roaming AppData (userappdata and appdata are the same)
Type: filesandordirs; Name: "{userappdata}\{#AppName}"
