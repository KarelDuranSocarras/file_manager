import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;

import '../env.dart';
import '../features/sync/data/datasources/app_database.dart';
import '../features/sync/data/datasources/drive_api_client.dart';
import '../features/sync/data/repositories/sync_repository.dart';
import '../features/sync/domain/services/sync_engine.dart';
import '../features/sync/presentation/bloc/sync_status_bloc.dart';

final sl = GetIt.instance;

Future<void> initDependencies({required String supportPath}) async {
  final db = await AppDatabase.open(p.join(supportPath, 'respaldo_drive.db'));
  final drive = DriveApiClient(
    Env.driveClientId,
    Env.driveClientSecret,
    Env.driveRefreshToken,
  );
  final repository = SyncRepository(db, drive);
  final engine = SyncEngine(repository);
  sl
    ..registerLazySingleton<AppDatabase>(() => db)
    ..registerLazySingleton<DriveApiClient>(() => drive)
    ..registerLazySingleton<SyncRepository>(() => repository)
    ..registerLazySingleton<SyncEngine>(() => engine)
    ..registerFactory<SyncStatusBloc>(() => SyncStatusBloc(engine));
}
