; Instalador de Respaldo Drive para Windows (Inno Setup 6)
; Sin firma de código en v1 (acuerdo §8.27).
; Compilar desde Windows:
;   1) flutter build windows --release
;   2) ISCC windows\installer.iss

#define AppName "Respaldo Drive"
#define AppVersion "0.1.0"

[Setup]
AppId={{8A2F6B34-9C1D-4E7A-B5F2-3D9E1C4A7B08}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppName}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename=instalador_respaldodrive_windows
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
UninstallDisplayIcon={app}\file_manager.exe

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\file_manager.exe"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\file_manager.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Crear acceso directo en el escritorio"; GroupDescription: "Accesos directos:"

[Run]
Filename: "{app}\file_manager.exe"; Description: "Iniciar {#AppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; La base de datos local se conserva al desinstalar (histórico de actividad
; y configuración); borra solo binarios instalados.
Type: filesandordirs; Name: "{app}\data"
