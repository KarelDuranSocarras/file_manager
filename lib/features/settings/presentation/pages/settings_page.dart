import 'package:flutter/material.dart';

import '../../../../app/di.dart';
import '../../../../app/notifications.dart';
import '../../../../app/theme.dart';
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
  bool _autoSync = true;
  bool _notifications = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _intervalMinutes = await _repo.scanIntervalMinutes();
    _exclusions = await _repo.customExclusions();
    _autoSync = await _repo.autoSyncEnabled();
    _notifications = await _repo.notificationsEnabled();
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _SettingsCard(
                icon: Icons.schedule,
                title: 'Frecuencia de sincronización',
                description:
                    'Con qué frecuencia se revisa la carpeta en busca de '
                    'cambios. Los archivos nuevos también se detectan al '
                    'momento mientras la app esté abierta.',
                child: DropdownButtonFormField<int>(
                  initialValue: _intervalMinutes,
                  items: const [
                    DropdownMenuItem(value: 5, child: Text('5 minutos')),
                    DropdownMenuItem(value: 10, child: Text('10 minutos')),
                    DropdownMenuItem(value: 15, child: Text('15 minutos')),
                    DropdownMenuItem(value: 30, child: Text('30 minutos')),
                    DropdownMenuItem(value: 60, child: Text('1 hora')),
                  ],
                  onChanged: _saveInterval,
                ),
              ),
              const SizedBox(height: 16),
              _SettingsCard(
                icon: Icons.tune,
                title: 'Preferencias',
                description:
                    'Controla cómo se comporta Respaldo Drive en tu '
                    'equipo.',
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Sincronización automática'),
                      subtitle: const Text(
                        'Revisa la carpeta y sube cambios cada cierto '
                        'tiempo. Si la desactivas, solo sincroniza con '
                        '"Sincronizar ahora" o al detectar cambios '
                        'mientras la app está abierta.',
                      ),
                      value: _autoSync,
                      activeThumbColor: AppTheme.coral,
                      onChanged: (value) async {
                        await _engine.setAutoSync(value);
                        if (mounted) setState(() => _autoSync = value);
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Notificaciones'),
                      subtitle: const Text(
                        'Avisos del sistema solo para problemas y avisos '
                        'importantes (sin conexión, cuota llena, errores).',
                      ),
                      value: _notifications,
                      activeThumbColor: AppTheme.coral,
                      onChanged: (value) async {
                        await _repo.setNotificationsEnabled(value);
                        sl<NotificationService>().setEnabled(value);
                        if (mounted) setState(() => _notifications = value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SettingsCard(
                icon: Icons.block,
                title: 'Archivos excluidos',
                description:
                    'Además de los temporales y ocultos del sistema, puedes '
                    'excluir por extensión (p. ej. .log) o por parte del '
                    'nombre. Se aplican también a los archivos nuevos.',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _exclusionController,
                            decoration: const InputDecoration(
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
                    if (_exclusions.isNotEmpty) ...[
                      const SizedBox(height: 12),
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.salmon.withValues(alpha: 0.25),
                  child: Icon(icon, size: 20, color: AppTheme.coralDark),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                color: AppTheme.ink.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
