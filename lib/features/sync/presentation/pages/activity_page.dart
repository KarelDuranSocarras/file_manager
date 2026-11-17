import 'package:flutter/material.dart';

import '../../../../app/di.dart';
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
            return const Center(child: Text('Sin actividad todavía.'));
          }
          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final (icon, color) = switch (entry.type) {
                ActivityType.info => (
                    Icons.check_circle_outline,
                    Colors.green,
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
              return ListTile(
                leading: Icon(icon, color: color),
                title: Text(entry.message),
                subtitle: entry.path == null
                    ? null
                    : Text(
                        entry.path!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                trailing: Text(
                  _format(entry.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            },
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
