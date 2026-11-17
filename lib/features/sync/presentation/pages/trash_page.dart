import 'package:flutter/material.dart';

import '../../../../app/di.dart';
import '../../data/repositories/sync_repository.dart';
import '../../domain/models/trash_entry.dart';

class TrashPage extends StatefulWidget {
  const TrashPage({super.key});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  final SyncRepository _repository = sl<SyncRepository>();
  late Future<List<TrashEntry>> _entries;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _entries = _repository.trashEntries();
  }

  Future<void> _undo(TrashEntry entry) async {
    try {
      await _repository.undoTrashEntry(entry);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo recuperar: $e')),
        );
      }
    }
    if (mounted) setState(_reload);
  }

  Future<void> _empty() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vaciar papelera'),
        content: const Text(
          'Se eliminarán definitivamente todos los archivos de la papelera. '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await _repository.emptyTrash();
      if (mounted) setState(_reload);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Papelera (15 días)'),
        actions: [
          IconButton(
            tooltip: 'Vaciar papelera',
            icon: const Icon(Icons.delete_forever),
            onPressed: _empty,
          ),
        ],
      ),
      body: FutureBuilder<List<TrashEntry>>(
        future: _entries,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data ?? const <TrashEntry>[];
          if (entries.isEmpty) {
            return const Center(
              child: Text('La papelera está vacía.'),
            );
          }
          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final daysLeft = entry.trashedAt
                  .add(const Duration(days: 15))
                  .difference(DateTime.now())
                  .inDays;
              return ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(entry.name),
                subtitle: Text(
                  '${entry.path}\nSe elimina en ${daysLeft < 0 ? 0 : daysLeft} día(s)',
                ),
                isThreeLine: true,
                trailing: TextButton(
                  onPressed: () => _undo(entry),
                  child: const Text('Deshacer'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
