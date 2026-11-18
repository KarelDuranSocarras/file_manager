import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart' show Size;
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../features/sync/domain/services/sync_engine.dart';
import 'di.dart';

/// Instancia única por puerto local: la segunda instancia pide mostrar
/// la ventana de la primera y termina (§5.16).
const int _singleInstancePort = 47219;

Future<void> _ensureSingleInstance() async {
  try {
    final server = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      _singleInstancePort,
    );
    server.listen((socket) {
      socket.listen((_) {
        _showWindow();
      });
      socket.destroy();
    });
  } on SocketException {
    try {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        _singleInstancePort,
        timeout: const Duration(seconds: 2),
      );
      socket.writeln('show');
      await socket.flush();
      socket.destroy();
    } catch (_) {
      // Sin la primera instancia: simplemente termina.
    }
    exit(0);
  }
}

void _showWindow() {
  windowManager.show();
  windowManager.focus();
}

/// Bandeja del sistema + ventana (X minimiza a bandeja, §5.15) +
/// autostart por defecto (§4.14).
class DesktopShell with WindowListener, TrayListener {
  bool _trayReady = false;

  Future<void> initialize() async {
    await _ensureSingleInstance();

    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(860, 620),
      minimumSize: Size(720, 480),
      title: 'Respaldo Drive',
      center: true,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);

    trayManager.addListener(this);
    await _setupTray();

    LaunchAtStartup.instance.setup(
      appName: 'Respaldo Drive',
      appPath: Platform.resolvedExecutable,
    );
    try {
      await LaunchAtStartup.instance.enable();
    } on Exception {
      // Sin autostart (p. ej. entorno de pruebas): la app sigue normal.
    }
  }

  Future<void> _setupTray() async {
    try {
      // El menú va ANTES del ícono: en Linux el indicador se crea con el
      // menú que ya esté construido; si se reemplaza después, el menú
      // exportado por D-Bus queda vacío y ningún clic muestra nada.
      await trayManager.setContextMenu(await _buildMenu());
      await trayManager.setIcon('assets/tray_icon_16.png');
      await trayManager.setToolTip('Respaldo Drive');
      _trayReady = true;
    } on Exception {
      // Escritorios sin bandeja (GNOME sin AppIndicator): la app sigue
      // funcionando desde la ventana; en Windows la bandeja es nativa.
      _trayReady = false;
    }
  }

  Future<Menu> _buildMenu() async {
    final paused = sl.isRegistered<SyncEngine>()
        ? sl<SyncEngine>().isPaused
        : false;
    return Menu(
      items: [
        MenuItem(
          key: 'open',
          label: 'Mostrar Respaldo Drive',
          onClick: (_) => _showWindow(),
        ),
        MenuItem(
          key: 'pause',
          label: paused ? 'Reanudar sincronización' : 'Detener sincronización',
          onClick: (_) {
            final engine = sl<SyncEngine>();
            paused ? engine.resume() : engine.pause();
            _setupTray();
          },
        ),
        MenuItem(
          key: 'sync',
          label: 'Sincronizar ahora',
          onClick: (_) => sl<SyncEngine>().syncNow(),
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'exit',
          label: 'Cerrar',
          onClick: (_) => exit(0),
        ),
      ],
    );
  }

  // --- TrayListener ---

  @override
  void onTrayIconMouseDown() {
    _showWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  // --- WindowListener ---

  @override
  void onWindowClose() async {
    // La X minimiza a la bandeja y el respaldo sigue en segundo plano;
    // salir de verdad es una acción explícita del menú de la bandeja.
    await windowManager.hide();
    if (_trayReady) {
      await _setupTray();
    }
  }
}
