import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'theme.dart';

/// Estructura visual común: barra lateral con el logo de la marca y
/// navegación entre secciones.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  int get _selectedIndex => switch (location) {
        '/actividad' => 1,
        '/papelera' => 2,
        '/ajustes' => 3,
        _ => 0,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) => context.go(switch (index) {
              1 => '/actividad',
              2 => '/papelera',
              3 => '/ajustes',
              _ => '/',
            }),
            extended: false,
            minExtendedWidth: 180,
            leading: Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Column(
                children: [
                  ClipOval(
                    child: Image.asset(
                      'assets/logo.jpg',
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Respaldo Drive',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppTheme.coralDark,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.cloud_upload_outlined),
                selectedIcon: Icon(Icons.cloud_upload),
                label: Text('Inicio'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: Text('Actividad'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.delete_outline),
                selectedIcon: Icon(Icons.delete),
                label: Text('Papelera'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Ajustes'),
              ),
            ],
          ),
          VerticalDivider(
            thickness: 1,
            width: 1,
            color: AppTheme.salmon.withValues(alpha: 0.5),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
