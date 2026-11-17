import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/sync/presentation/bloc/sync_status_bloc.dart';
import 'di.dart';
import 'router.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SyncStatusBloc>(
      create: (_) => sl<SyncStatusBloc>()..add(const SyncStatusStarted()),
      child: MaterialApp.router(
        title: 'Respaldo Drive',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        routerConfig: appRouter,
      ),
    );
  }
}
