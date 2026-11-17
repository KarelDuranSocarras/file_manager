# Respaldo Drive

App de escritorio (Windows y Linux) que respalda automáticamente una
carpeta local en Google Drive: solo sube (última versión gana), guarda
los borrados en una papelera recuperable de 15 días y permite restaurar
todo en un equipo nuevo.

## Antes de compilar o usar

1. Copia `.env.example` como `.env` en la raíz y rellena tus credenciales
   de Google Drive (client ID, client secret y refresh token). Este
   archivo nunca se comparte: se compila dentro de la app.
2. Regenera los secretos:
   ```
   dart run build_runner build
   ```

> Si `pub`/`flutter` fallan con "authorization failed", exporta antes:
> ```
> export PUB_HOSTED_URL="https://pub.flutter-io.cn"
> export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
> ```

## Uso en Windows

### Instalar
1. Ejecuta `dist\instalador_respaldodrive_windows.exe` (ver
   `docs/DISTRIBUCION.md` para generarlo).
2. Sigue el asistente; puede iniciarse al terminar.
3. La app arranca con el inicio automático de Windows activado.

### Uso diario
- Al abrir, elige con el botón de carpeta **la carpeta a respaldar**:
  todo lo de dentro se subirá a Google Drive automáticamente.
- Los cambios nuevos se detectan al momento y se suben cuando el
  archivo lleva estable un par de minutos.
- **Cerrar la ventana (X) no apaga la app**: queda en la bandeja del
  sistema (ícono de nube). Para salir del todo: clic derecho en el
  ícono de la bandeja → **Salir**.
- Menú de la bandeja: **Abrir**, **Pausar/Reanudar**,
  **Sincronizar ahora** y **Salir**.
- Desde la ventana principal:
  - **Actividad** (historial): qué se subió, falló o avisó.
  - **Ajustes**: cambiar cada cuánto sincroniza y añadir exclusiones
    propias (p. ej. `.log`).
  - **Papelera**: recupera archivos borrados (botón **Deshacer**) o
    vacíala; a los 15 días se borran solos de Drive.
  - **Restaurar** (icono en la barra): descarga todo el respaldo a la
    carpeta original (útil en un equipo nuevo; no sobreescribe nada
    que ya exista localmente).
- Avisos que verás (ventana y notificaciones): cuota de Drive al
  80/95/100 %, más de 1 hora sin conexión, y carpeta desaparecida
  (tú decides: reintentar, elegir otra carpeta o vaciar el respaldo
  en la nube).

## Uso en Linux

### Instalar
1. Necesitas `libnotify` (suele venir preinstalado).
2. Da permisos de ejecución y lanza:
   ```
   chmod +x RespaldoDrive-x86_64.AppImage
   ./RespaldoDrive-x86_64.AppImage
   ```
3. Opcional: mueve el archivo a `~/Applications/` y tu entorno de
   escritorio lo listará en el menú de aplicaciones.
4. La app activa su arranque automático al iniciar sesión.

### Uso diario
Igual que en Windows: misma ventana, bandeja del sistema, papelera de
15 días, restauración completa y avisos. El botón X minimiza a la
bandeja y **Salir** solo está en el menú de la bandeja.

## Compilar tú mismo

| Objetivo | Comando |
|---|---|
| Probar en desarrollo | `flutter run -d linux` o `-d windows` |
| AppImage (Linux) | `./scripts/build_appimage.sh x64` |
| Instalador .exe (Windows) | `flutter build windows --release` y luego `ISCC windows\installer.iss` |

Detalles completos en `docs/DISTRIBUCION.md`; el acuerdo del producto
está en `docs/ACUERDO.md`.

## CI automático (GitHub Actions)

Al subir a GitHub (rama `main`), el workflow `.github/workflows/build.yml`
compila y prueba todo automáticamente:

- **Windows**: instalador `.exe` (Inno Setup) como artefacto descargable.
- **Linux**: `RespaldoDrive-x86_64.AppImage` como artefacto descargable.
- Al crear un tag `v*` (p. ej. `v0.1.0`) publica ambos instaladores en
  un Release de GitHub.

Configura una sola vez, en *Settings → Secrets and variables → Actions*,
los secretos del repositorio (los mismos del `.env`):

- `DRIVE_CLIENT_ID`
- `DRIVE_CLIENT_SECRET`
- `DRIVE_REFRESH_TOKEN`
