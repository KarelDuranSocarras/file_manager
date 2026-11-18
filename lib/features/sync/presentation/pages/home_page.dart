import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_selector/file_selector.dart';

import '../../../../app/theme.dart';
import '../bloc/sync_status_bloc.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final statusBloc = context.read<SyncStatusBloc>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: BlocBuilder<SyncStatusBloc, SyncStatusState>(
              builder: (context, state) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StatusCard(state: state),
                    const SizedBox(height: 16),
                    _ActionRow(state: state, statusBloc: statusBloc),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state});

  final SyncStatusState state;

  @override
  Widget build(BuildContext context) {
    final (icon, color, title, subtitle, progress) = _map(state);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink,
                  ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.ink.withValues(alpha: 0.7),
                    ),
              ),
            ],
            if (progress != null) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ],
        ),
      ),
    );
  }

  (IconData, Color, String, String?, double?) _map(SyncStatusState state) {
    return switch (state) {
      SyncStatusInitial() => (
          Icons.hourglass_top,
          AppTheme.salmon,
          'Iniciando…',
          null,
          null,
        ),
      SyncStatusNotConfigured() => (
          Icons.folder_open,
          AppTheme.coral,
          'Configura tu carpeta',
          'Elige con el botón de abajo la carpeta que quieres respaldar '
              'en Google Drive.',
          null,
        ),
      SyncStatusScanning() => (
          Icons.manage_search,
          AppTheme.coral,
          'Buscando cambios…',
          null,
          null,
        ),
      SyncStatusUpToDate() => (
          Icons.check_circle,
          Colors.green.shade600,
          'Todo al día',
          'Tu respaldo está sincronizado con Google Drive.',
          null,
        ),
      SyncStatusUploading(:final fileName) => (
          Icons.cloud_upload,
          AppTheme.coral,
          'Subiendo: $fileName',
          null,
          null,
        ),
      SyncStatusPaused() => (
          Icons.pause_circle,
          Colors.orange.shade700,
          'Sincronización en pausa',
          'Pulsa Reanudar o usa el menú de la bandeja para continuar.',
          null,
        ),
      SyncStatusWaitingConnection() => (
          Icons.cloud_off,
          Colors.orange.shade700,
          'Sin conexión',
          'Esperando conexión para subir cambios. Todo queda guardado '
              'en la cola.',
          null,
        ),
      SyncStatusOfflineWarning() => (
          Icons.cloud_off,
          Colors.red.shade600,
          'Sin conexión por más de 1 hora',
          'Los cambios quedan en cola y se subirán al volver la conexión.',
          null,
        ),
      SyncStatusQuotaWarning(:final message) => (
          Icons.data_usage,
          Colors.red.shade600,
          message,
          null,
          null,
        ),
      SyncStatusFolderMissing() => (
          Icons.folder_off,
          Colors.red.shade600,
          'Carpeta no disponible',
          'Tu copia en la nube está intacta. Decide qué hacer abajo.',
          null,
        ),
      SyncStatusError(:final message) => (
          Icons.error_outline,
          Colors.red.shade600,
          'Error',
          message,
          null,
        ),
      SyncStatusRestoring(:final done, :final total) => (
          Icons.cloud_download,
          AppTheme.coral,
          total == 0 ? 'Preparando restauración…' : 'Restaurando…',
          total == 0 ? null : '$done de $total archivos',
          total == 0 ? null : done / total,
        ),
      SyncStatusRestoreOffer(:final fileCount) => (
          Icons.cloud_download,
          AppTheme.coral,
          'Restaurar respaldo',
          'Hay un respaldo con $fileCount archivo(s) en esta cuenta. '
              '¿Quieres restaurarlo aquí?',
          null,
        ),
    };
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.state, required this.statusBloc});

  final SyncStatusState state;
  final SyncStatusBloc statusBloc;

  @override
  Widget build(BuildContext context) {
    final isPaused = state is SyncStatusPaused;
    final busy =
        state is SyncStatusRestoring || state is SyncStatusRestoreOffer;

    if (state is SyncStatusRestoreOffer) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () =>
                  statusBloc.add(const RestoreAllRequested()),
              icon: const Icon(Icons.restore),
              label: const Text('Restaurar todo'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () =>
                statusBloc.add(const RestoreOfferDismissed()),
            child: const Text('No ahora'),
          ),
        ],
      );
    }

    if (state is SyncStatusFolderMissing) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => statusBloc.add(const SyncNowRequested()),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final path = await getDirectoryPath();
                if (path != null && context.mounted) {
                  statusBloc.add(FolderSelected(path));
                }
              },
              icon: const Icon(Icons.folder_open),
              label: const Text('Elegir otra carpeta'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _confirmTrashCloud(context),
            child: const Text('La carpeta ya no existe: vaciar respaldo '
                'en la nube'),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: busy ? null : () => statusBloc.add(const SyncNowRequested()),
            icon: const Icon(Icons.sync),
            label: const Text('Sincronizar ahora'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => statusBloc.add(
              isPaused
                  ? const ResumeSyncRequested()
                  : const PauseSyncRequested(),
            ),
            icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
            label: Text(isPaused ? 'Reanudar' : 'Pausar'),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmTrashCloud(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enviar copia a la papelera'),
        content: const Text(
          'Se enviará toda la copia en Google Drive a la papelera '
          '(recuperable durante 15 días). ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Enviar a la papelera'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      statusBloc.add(const FolderMissingTrashCloud());
    }
  }
}
