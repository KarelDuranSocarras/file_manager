import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_selector/file_selector.dart';
import 'package:go_router/go_router.dart';

import '../bloc/sync_status_bloc.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final statusBloc = context.read<SyncStatusBloc>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Respaldo Drive'),
        actions: [
          BlocBuilder<SyncStatusBloc, SyncStatusState>(
            builder: (context, state) {
              final paused = state is SyncStatusPaused;
              return IconButton(
                tooltip: paused
                    ? 'Reanudar sincronización'
                    : 'Pausar sincronización',
                icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                onPressed: () => statusBloc.add(
                  paused
                      ? const ResumeSyncRequested()
                      : const PauseSyncRequested(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Restaurar todo desde Drive',
            icon: const Icon(Icons.restore),
            onPressed: () =>
                statusBloc.add(const RestoreAllRequested()),
          ),
          IconButton(
            tooltip: 'Actividad',
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/actividad'),
          ),
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/ajustes'),
          ),
          IconButton(
            tooltip: 'Papelera',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => context.push('/papelera'),
          ),
        ],
      ),
      body: Center(
        child: BlocBuilder<SyncStatusBloc, SyncStatusState>(
          builder: (context, state) {
            return switch (state) {
              SyncStatusInitial() => const CircularProgressIndicator(),
              SyncStatusNotConfigured() => const Text(
                  'Configura la carpeta a respaldar para comenzar.'),
              SyncStatusScanning() => const Text('Buscando cambios…'),
              SyncStatusPaused() => const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pause_circle, size: 48),
                    SizedBox(height: 12),
                    Text('Sincronización en pausa.\n'
                        'Pulsa play o usa el menú de la bandeja para '
                        'reanudar.'),
                  ],
                ),
              SyncStatusUpToDate() => const Text('Todo al día.'),
              SyncStatusUploading(:final fileName) =>
                Text('Subiendo: $fileName'),
              SyncStatusFolderMissing() => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.folder_off, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'La carpeta respaldada no está disponible.\n'
                      'Tu copia en la nube está intacta. ¿Qué quieres hacer?',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                      onPressed: () =>
                          statusBloc.add(const SyncNowRequested()),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final path = await getDirectoryPath();
                        if (path != null && context.mounted) {
                          statusBloc.add(FolderSelected(path));
                        }
                      },
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Elegir otra carpeta'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Enviar copia a la papelera'),
                            content: const Text(
                              'Se enviará toda la copia en Google Drive a '
                              'la papelera (recuperable durante 15 días). '
                              '¿Continuar?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, false),
                                child: const Text('Cancelar'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, true),
                                child: const Text('Enviar a la papelera'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true && context.mounted) {
                          statusBloc.add(const FolderMissingTrashCloud());
                        }
                      },
                      child: const Text('La carpeta ya no existe: vaciar '
                          'respaldo en la nube'),
                    ),
                  ],
                ),
              SyncStatusWaitingConnection() => const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'Sin conexión: esperando para subir cambios.\n'
                      'Todo queda guardado en la cola.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              SyncStatusOfflineWarning() => const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'Sin conexión con Google Drive por más de 1 hora.\n'
                      'Los cambios quedan en cola y se subirán al volver '
                      'la conexión.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              SyncStatusQuotaWarning(:final message) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.data_usage, size: 48),
                    const SizedBox(height: 12),
                    Text(message, textAlign: TextAlign.center),
                  ],
                ),
              SyncStatusError(:final message) => Text('Error: $message'),
              SyncStatusRestoring(:final done, :final total) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      total == 0
                          ? 'Preparando restauración…'
                          : 'Restaurando $done de $total…',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 240,
                      child: LinearProgressIndicator(
                        value: total == 0 ? null : done / total,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => statusBloc
                          .add(const CancelRestoreRequested()),
                      child: const Text('Cancelar'),
                    ),
                  ],
                ),
              SyncStatusRestoreOffer(:final fileCount) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_download, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Hay un respaldo con $fileCount archivo(s) en esta '
                      'cuenta.\n¿Quieres restaurarlos en esta carpeta?',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => statusBloc
                          .add(const RestoreAllRequested()),
                      child: const Text('Restaurar todo'),
                    ),
                    TextButton(
                      onPressed: () => statusBloc
                          .add(const RestoreOfferDismissed()),
                      child: const Text('No ahora'),
                    ),
                  ],
                ),
            };
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final path = await getDirectoryPath();
          if (path != null && context.mounted) {
            statusBloc.add(FolderSelected(path));
          }
        },
        tooltip: 'Elegir carpeta a respaldar',
        child: const Icon(Icons.folder_open),
      ),
    );
  }
}
