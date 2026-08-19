#ifndef PublishDir
  #error PublishDir must be provided with /DPublishDir=...
#endif
#ifndef OutputDir
  #define OutputDir "."
#endif
#ifndef AppVersion
  #define AppVersion "0.1.3.10"
#endif
#ifndef IconFile
  #error IconFile must be provided with /DIconFile=...
#endif
#ifndef AllowedArchitectures
  #define AllowedArchitectures "x64compatible"
#endif
#ifndef OutputBaseFilename
  #define OutputBaseFilename "LocalStoreManagement-Setup-win-x64"
#endif

#define AppName "Local Store Management System"
#define AppExeName "local_store_management.exe"

[Setup]
AppId={{80CDB06E-303B-4F9F-B763-404CF2ABF0B6}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=MaydayAlaska
DefaultDirName={localappdata}\Programs\Local Store Management System
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed={#AllowedArchitectures}
ArchitecturesInstallIn64BitMode={#AllowedArchitectures}
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBaseFilename}
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
