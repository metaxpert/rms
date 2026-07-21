import 'package:flutter/material.dart';
import 'src/api.dart';
import 'src/theme.dart';
import 'src/screens/login_screen.dart';
import 'src/screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.instance.load();
  runApp(const ManagerApp());
}

class ManagerApp extends StatelessWidget {
  const ManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RMS Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Api.instance.isAuthed ? const HomeShell() : const LoginScreen(),
    );
  }
}
