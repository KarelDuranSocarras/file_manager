import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/desktop_shell.dart';
import 'app/di.dart';
import 'app/notifications.dart';
import 'features/sync/data/repositories/sync_repository.dart';
import 'features/sync/domain/services/sync_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final supportDir = await getApplicationSupportDirectory();
  await initDependencies(supportPath: supportDir.path);
  await DesktopShell().initialize();
  final notifications = NotificationService();
  await notifications.initialize();
  notifications.setEnabled(await sl<SyncRepository>().notificationsEnabled());
  notifications.listen(sl<SyncEngine>());
  runApp(const App());
}
