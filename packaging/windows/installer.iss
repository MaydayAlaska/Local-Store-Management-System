#ifndef PublishDir
  #error PublishDir must be provided with /DPublishDir=...
#endif

#ifndef OutputDir
  #define OutputDir "."
#endif

#ifndef AppVersion
  #define AppVersion "0.1.1"
#endif

#ifndef IconFile
  #error IconFile must be provided with /DIconFile=...
#endif

#define AppName "Local Store Management System"
#define AppExeName "LocalStoreManagement.Desktop.exe"

[Setup]
AppId={{80CDB06E-303B-4F9F-B763-404CF2ABF0B6}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=MaydayAlaska
DefaultDirName={localappdata}\Programs\Local Store Management System
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename=LocalStoreManagement-Setup-win-x64
SetupIconFile={#IconFile}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UsePreviousAppDir=yes
CloseApplications=yes
RestartApplications=no
UninstallDisplayIcon={app}\{#AppExeName}

[Tasks]
Name: "desktopicon"; Description: "Crea un collegamento sul desktop"; GroupDescription: "Collegamenti aggiuntivi:"; Flags: unchecked

[Files]
Source: "{#PublishDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Avvia {#AppName}"; Flags: nowait postinstall skipifsilent
