import 'package:flutter/material.dart';

import '../../../../app/di.dart';
import '../../../../app/theme.dart';
import '../../data/repositories/sync_repository.dart';
import '../../domain/models/trash_entry.dart';

class TrashPage extends StatelessWidget {
  const TrashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = sl<SyncRepository>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Papelera'),
        actions: [
          IconButton(
            tooltip: 'Vaciar papelera',
            icon: const Icon(Icons.delete_forever),
            onPressed: () => _confirmEmpty(context, repo),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<TrashEntry>>(
        future: repo.trashEntries(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data!;
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_outline,
                      size: 48,
                      color: AppTheme.salmon.withValues(alpha: 0.8)),
                  const SizedBox(height: 12),
                  Text(
                    'La papelera está vacía',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Los archivos borrados localmente se recuperan '
                    'aquí durante 15 días.',
                    style: TextStyle(
                      color: AppTheme.ink.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final daysLeft = entry.trashedAt
                          .add(const Duration(days: 15))
                          .difference(DateTime.now())
                          .inDays;
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        radius: 18,
                        child: Icon(Icons.description_outlined, size: 20),
                      ),
                      title: Text(
                        entry.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.ink,
                        ),
                      ),
                      subtitle: Text(
                        entry.path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.ink.withValues(alpha: 0.55),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Chip(
                            label: Text(
                              '$daysLeft días',
                              style: const TextStyle(fontSize: 12),
                            ),
                            avatar: const Icon(Icons.schedule, size: 16),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Deshacer (volver a Drive)',
                            icon: const Icon(Icons.undo),
                            onPressed: () => _undo(context, repo, entry),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _undo(
    BuildContext context,
    SyncRepository repo,
    TrashEntry entry,
  ) async {
    try {
      await repo.undoTrashEntry(entry);
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo deshacer: revisa tu conexión'),
          ),
        );
      }
    }
  }

  Future<void> _confirmEmpty(
    BuildContext context,
    SyncRepository repo,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Vaciar papelera'),
        content: const Text(
          'Se eliminará definitivamente todo lo que está en la papelera '
          'de Google Drive. Esta acción no se puede deshacer. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await repo.emptyTrash();
    }
  }
}
