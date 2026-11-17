import 'package:local_notifier/local_notifier.dart';

import '../features/sync/domain/services/sync_engine.dart';

/// Notificaciones nativas minimalistas: solo errores y eventos críticos
/// (§4.12). Nada de avisar subidas normales.
class NotificationService {
  Future<void> initialize() async {
    await localNotifier.setup(appName: 'Respaldo Drive');
  }

  void listen(SyncEngine engine) {
    engine.events.listen((event) {
      switch (event) {
        case EngineOfflineWarning():
          _notify(
            'Sin conexión con Google Drive',
            'Más de 1 hora sin conexión. Los cambios quedan en cola y se '
            'subirán al volver.',
          );
        case EngineQuotaWarning(:final message):
          if (message.contains('agotada')) {
            _notify('Espacio agotado en Google Drive', message);
          }
        case EngineFolderMissing():
          _notify(
            'Carpeta no disponible',
            'La carpeta respaldada no está accesible. Tu copia en la nube '
            'está intacta.',
          );
        case EngineError(:final message):
          _notify('Respaldo Drive: error', message);
        case EngineNotConfigured():
        case EngineScanning():
        case EngineUploading():
        case EngineUpToDate():
        case EngineWaitingConnection():
        case EnginePaused():
        case EngineResumed():
        case EngineRestoring():
        case EngineRestoreOffer():
          break;
      }
    });
  }

  void _notify(String title, String body) {
    final notification = LocalNotification(title: title, body: body);
    localNotifier.notify(notification);
  }
}
