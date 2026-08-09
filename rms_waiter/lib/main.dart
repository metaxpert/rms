import 'package:flutter/material.dart';
import 'src/api.dart';
import 'src/theme.dart';
import 'src/screens/login_screen.dart';
import 'src/screens/branch_screen.dart';
import 'src/screens/tables_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.instance.load();
  runApp(const WaiterApp());
}

class WaiterApp extends StatelessWidget {
  const WaiterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RMS Waiter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: !Api.instance.isAuthed
          ? const LoginScreen()
          : Api.instance.branchId == null
              ? const BranchScreen()
              : const TablesScreen(),
    );
  }
}
