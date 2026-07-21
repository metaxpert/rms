import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import 'menu_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(text: 'chef@karahipoint.test');
  final _password = TextEditingController(text: 'Password123!');
  final _base = TextEditingController(text: Api.instance.baseUrl);
  bool _busy = false;
  String? _error;
  bool _showAdvanced = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _base.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final nav = Navigator.of(context);
    try {
      await Api.instance.setBase(_base.text);
      await Api.instance.login(_email.text.trim(), _password.text);
      nav.pushReplacement(MaterialPageRoute(builder: (_) => const MenuScreen()));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not reach the server. Check the API address.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.ramen_dining, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 16),
                const Text('Karahi Point', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                const Text('Order your favourites', style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 24),
                TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                TextField(controller: _password, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
                if (_showAdvanced) ...[
                  const SizedBox(height: 12),
                  TextField(controller: _base, decoration: const InputDecoration(labelText: 'API address')),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Color(0xFFA02840))),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _login,
                  child: _busy
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Start ordering'),
                ),
                TextButton(
                  onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
                  child: Text(_showAdvanced ? 'Hide server settings' : 'Server settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
