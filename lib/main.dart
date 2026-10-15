import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/task_repository.dart';
import 'providers/task_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/task_list_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaskManagerApp());
}

class TaskManagerApp extends StatelessWidget {
  const TaskManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => TaskProvider(SqliteTaskRepository())..load(),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => MaterialApp(
          title: 'Task Manager',
          debugShowCheckedModeBanner: false,
          themeMode: theme.mode,
          theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
          darkTheme: ThemeData(
            colorSchemeSeed: Colors.indigo,
            brightness: Brightness.dark,
            useMaterial3: true,
          ),
          home: const TaskListScreen(),
        ),
      ),
    );
  }
}
