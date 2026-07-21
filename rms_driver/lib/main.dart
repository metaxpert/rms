import 'package:flutter/material.dart';
import 'src/api.dart';
import 'src/theme.dart';
import 'src/screens/login_screen.dart';
import 'src/screens/deliveries_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.instance.load();
  runApp(const DriverApp());
}

class DriverApp extends StatelessWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RMS Driver',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Api.instance.isAuthed ? const DeliveriesScreen() : const LoginScreen(),
    );
  }
}
