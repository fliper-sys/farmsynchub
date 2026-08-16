; Inno Setup script for FarmSync Hub (Windows desktop installer).
;
; Prerequisites:
;   1. Build the release binaries first:  flutter build windows --release
;   2. Compile this script with Inno Setup (ISCC.exe), either via the IDE
;      or:  iscc windows\installer\farmsynchub.iss
;
; Bump MyAppVersion below whenever pubspec.yaml's version changes, so the
; installer filename and "About" version stay in sync with the app.

#define MyAppName "FarmSync Hub"
#define MyAppVersion "1.0.13"
#define MyAppPublisher "FarmSync Hub"
#define MyAppExeName "farmsynchub.exe"
#define MyReleaseDir "..\..\build\windows\x64\runner\Release"

[Setup]
; This AppId stays constant across releases so Inno Setup recognizes an
; existing install and upgrades in place instead of creating a duplicate.
AppId={{F39BF039-183B-44A6-9C79-DD5B53EF1532}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\..\dist
OutputBaseFilename=FarmSyncHub-Setup-{#MyAppVersion}
SetupIconFile=..\runner\resources\app_icon.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}
PrivilegesRequired=lowest

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Files]
Source: "{#MyReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
