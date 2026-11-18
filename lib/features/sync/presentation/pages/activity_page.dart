import 'package:flutter/material.dart';

import '../../../../app/di.dart';
import '../../../../app/theme.dart';
import '../../data/datasources/app_database.dart';
import '../../domain/models/activity_entry.dart';

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = sl<AppDatabase>();
    return Scaffold(
      appBar: AppBar(title: const Text('Actividad')),
      body: FutureBuilder<List<ActivityEntry>>(
        future: db.recentActivity(),
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
                  Icon(Icons.history,
                      size: 48, color: AppTheme.salmon.withValues(alpha: 0.8)),
                  const SizedBox(height: 12),
                  Text(
                    'Sin actividad todavía',
                    style: Theme.of(context).textTheme.bodyLarge,
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
                  final (icon, color) = switch (entry.type) {
                    ActivityType.info => (
                        Icons.check_circle_outline,
                        Colors.green.shade600,
                      ),
                    ActivityType.warning => (
                        Icons.warning_amber_outlined,
                        Colors.orange,
                      ),
                    ActivityType.error => (
                        Icons.error_outline,
                        Colors.red,
                      ),
                  };
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: color.withValues(alpha: 0.12),
                        child: Icon(icon, size: 20, color: color),
                      ),
                      title: Text(
                        entry.message,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.ink,
                        ),
                      ),
                      subtitle: entry.path == null
                          ? null
                          : Text(
                              entry.path!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.ink.withValues(alpha: 0.55),
                              ),
                            ),
                      trailing: Text(
                        _format(entry.createdAt),
                        style: TextStyle(
                          color: AppTheme.ink.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
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

  static String _format(DateTime time) {
    final local = time.toLocal();
    String two(int v) => '$v'.padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
