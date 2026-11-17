# AGENTS.md

## Overview

`Respaldo Drive` — app de escritorio (Windows/Linux) que respalda una carpeta local en Google Drive (solo sube, última versión gana, papelera de borrados 15 días, restauración completa). El acuerdo completo y vinculante del producto está en `docs/ACUERDO.md`: léelo antes de cualquier trabajo de features; cambiarlo requiere acuerdo explícito con el usuario.

Stack: Flutter Desktop (Dart). Estado: `bloc`/`flutter_bloc` · DI: `get_it` · navegación: `go_router` · red: `dio` (Drive REST v3) · secretos: `envied` · vigilancia de archivos: `watcher` · DB local: `sqflite_common_ffi` · selector de carpetas: `file_selector` · `path` (dependencia directa) · bandeja: `tray_manager` · ventana: `window_manager` · autostart: `launch_at_startup` · notificaciones: `local_notifier`. Fases 1–5 implementadas y probadas (subida con cola persistente; papelera de 15 días con deshacer y restauración completa; avisos de cuota 80/95/100 %, aviso único tras 1 h sin conexión, carpeta desaparecida con decisión del usuario; bandeja con pausar/reanudar/sincronizar/salir, X→bandeja, instancia única por puerto local 47219, autostart activado por defecto; lista de actividad, ajustes de intervalo y exclusiones, notificaciones nativas solo de errores/críticos). Fase 6: empaquetado preparado (docs/DISTRIBUCION.md, windows/installer.iss para Inno Setup, scripts/build_appimage.sh para AppImage, ícono .ico en el runner de Windows); compilar Windows requiere máquina Windows, la AppImage requiere `libnotify-dev`. Fase 7 (pruebas de los 8 pasos de beta en equipo real con .env) pendiente.

## Reglas

- **Toda librería nueva requiere aprobación explícita del usuario antes de agregarse.**
- Nunca loguear contenido de archivos ni credenciales (acuerdo §9.32).
- Interfaz solo en español.

## Commands

- `export PUB_HOSTED_URL="https://pub.flutter-io.cn" && export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"` — **requerido antes de cualquier comando pub/flutter**; sin esto pub.dev falla con "authorization failed". Las variables NO persisten entre invocaciones de shell: incluir en cada llamada.
- `flutter analyze` — verificación principal tras cada cambio.
- `dart run build_runner build` — regenera `lib/env.g.dart` (envied). Necesario tras cambiar `.env` o `lib/env.dart`.
- `flutter test` — pruebas en `test/` (dominio + repositorio con SQLite en memoria y Drive falso). Correrlas tras cada cambio.
- `flutter run -d windows` / `-d linux`.
- `flutter pub get` tras cambiar `pubspec.yaml`; `pubspec.lock` está commiteado.

## Gotchas

- El proyecto requiere un `.env` en la raíz (copiar `.env.example` y rellenar) o `envied`/codegen falla. `.env` y `lib/env.g.dart` están en `.gitignore` (contienen secretos; nunca commitarlos).
- Este directorio no es un repositorio git — git commands no tienen efecto; no intentarlos sin inicializar version control primero.
- Requiere Dart SDK `^3.12.2` (Flutter 3.44.x verificado). Si algo falla por SDK, revisar `flutter --version`.
