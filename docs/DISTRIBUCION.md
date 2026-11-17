# Distribución (Fase 6)

Cómo generar los instaladores de Respaldo Drive. Sin firma de código en
v1 (acuerdo §8.27); las actualizaciones se entregan a mano (§8.29).

## Windows: instalador `.exe` (Inno Setup)

En una máquina con Windows y Flutter:

1. Compilar la app:
   ```
   flutter build windows --release
   ```
2. Instalar [Inno Setup 6](https://jrsoftware.org/isinfo.php) si falta.
3. Compilar el instalador (desde la raíz del proyecto):
   ```
   ISCC windows\installer.iss
   ```
4. El instalador queda en `dist\instalador_respaldodrive_windows.exe`.

Notas:
- El ícono del ejecutable vive en `windows/runner/resources/app_icon.ico`
  (ya reemplazado por el ícono de la app).
- La desinstalación no borra la base de datos local del usuario: queda en
  `%APPDATA%` del directorio de soporte (histórico y configuración).
- Sin firma: Windows SmartScreen mostrará advertencia; es aceptado en v1.

## Linux: AppImage

Requisitos del sistema (una sola vez):

```
sudo apt install libnotify-dev
```

Luego, desde la raíz del proyecto:

```
./scripts/build_appimage.sh x64
```

El script compila en release, arma el AppDir y ejecuta `appimagetool`
(se descarga en `tools/` si falta). Resultado:
`dist/RespaldoDrive-x86_64.AppImage`.

Notas:
- La AppImage incluye la librería de libnotify empaquetada en el bundle;
  solo se necesita `libnotify-dev` para compilar.
- El puerto 47219 (instancia única) debe quedar libre en el equipo.

## Prueba final (checklist de la beta)

1. Instalar en un equipo limpio con `.env` real compilado.
2. Elegir carpeta, editar un archivo y verificar subida en Drive.
3. Borrar un archivo local → papelera → Deshacer → vuelve a Drive.
4. Vaciar papelera y esperar 15 días simulados → purga definitiva.
5. Desconectar red >1 h → aviso único; reconectar → sube cola.
6. Borrar carpeta local → mensaje con 3 opciones; probar "vaciar
   respaldo en la nube".
7. X de la ventana → sigue en bandeja; "Salir" termina todo.
8. Segunda instancia no abre ventana nueva.
