import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/environment.dart';
import '../providers.dart';
import '../theme/app_theme.dart';

/// Where staff point the app at their server.
///
/// Restaurants run on a LAN address as often as a domain, so this must be
/// editable in the field — but it is deliberately behind a sheet on the sign-in
/// screen rather than in normal navigation, because a mistyped base URL takes
/// the whole till offline.
class ServerSettingsSheet extends ConsumerStatefulWidget {
  const ServerSettingsSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => const ServerSettingsSheet(),
      );

  @override
  ConsumerState<ServerSettingsSheet> createState() =>
      _ServerSettingsSheetState();
}

class _ServerSettingsSheetState extends ConsumerState<ServerSettingsSheet> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: ref.read(sessionProvider).baseUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter the server address';
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'Include http:// or https://';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'Address must start with http:// or https://';
    }
    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref.read(sessionProvider).setBaseUrl(_controller.text);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final env = Environment.current;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.sm,
        // Keep the field above the keyboard.
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Server settings', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'The address of your restaurant server. Ask your manager if you '
              'are not sure.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xl),
            TextFormField(
              controller: _controller,
              autocorrect: false,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              validator: _validate,
              decoration: const InputDecoration(
                labelText: 'Server address',
                hintText: 'https://rms.example.com/api',
                prefixIcon: Icon(Icons.dns_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: theme.colorScheme.outline),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Default for this build (${env.label}): ${env.defaultApiBase}',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
