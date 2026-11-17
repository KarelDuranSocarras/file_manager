import 'package:flutter/material.dart';

import '../../../../app/di.dart';
import '../../../sync/data/repositories/sync_repository.dart';
import '../../../sync/domain/services/sync_engine.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SyncRepository _repo = sl<SyncRepository>();
  final SyncEngine _engine = sl<SyncEngine>();

  final TextEditingController _exclusionController = TextEditingController();
  List<String> _exclusions = const [];
  int _intervalMinutes = 15;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _intervalMinutes = await _repo.scanIntervalMinutes();
    _exclusions = await _repo.customExclusions();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _exclusionController.dispose();
    super.dispose();
  }

  Future<void> _saveInterval(int? minutes) async {
    if (minutes == null) return;
    await _engine.setScanInterval(Duration(minutes: minutes));
    if (mounted) setState(() => _intervalMinutes = minutes);
  }

  Future<void> _addExclusion() async {
    final value = _exclusionController.text.trim();
    if (value.isEmpty) return;
    final updated = [..._exclusions, value];
    await _repo.setCustomExclusions(updated);
    _exclusionController.clear();
    if (mounted) setState(() => _exclusions = updated);
  }

  Future<void> _removeExclusion(String value) async {
    final updated = [..._exclusions]..remove(value);
    await _repo.setCustomExclusions(updated);
    if (mounted) setState(() => _exclusions = updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Frecuencia de sincronización',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _intervalMinutes,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Sincronizar cada',
            ),
            items: const [
              DropdownMenuItem(value: 5, child: Text('5 minutos')),
              DropdownMenuItem(value: 10, child: Text('10 minutos')),
              DropdownMenuItem(value: 15, child: Text('15 minutos')),
              DropdownMenuItem(value: 30, child: Text('30 minutos')),
              DropdownMenuItem(value: 60, child: Text('1 hora')),
            ],
            onChanged: _saveInterval,
          ),
          const SizedBox(height: 24),
          Text('Archivos excluidos',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Además de los temporales y ocultos del sistema. Escribe una '
            'extensión (p. ej. .log) o parte del nombre a excluir.',
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _exclusionController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Nueva exclusión',
                    hintText: '.log',
                  ),
                  onSubmitted: (_) => _addExclusion(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: _addExclusion,
                icon: const Icon(Icons.add),
                label: const Text('Agregar'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _exclusions
                .map(
                  (value) => InputChip(
                    label: Text(value),
                    onDeleted: () => _removeExclusion(value),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
