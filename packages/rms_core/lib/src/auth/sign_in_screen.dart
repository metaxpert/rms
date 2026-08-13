import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/environment.dart';
import '../providers.dart';
import '../l10n/strings.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import 'auth_controller.dart';
import 'server_settings_sheet.dart';

/// Sign in. Shared by all four apps.
///
/// The journey is identical everywhere — the same endpoint, the same rotating
/// refresh token, the same "which outlet?" question afterwards — and it was
/// previously written out four times, which is how four copies of the same
/// missing token refresh got shipped. What genuinely differs between a waiter's
/// till and a rider's phone is the wording and the icon, so those are the only
/// things this takes.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({
    super.key,
    required this.title,
    this.icon = Icons.restaurant_menu_rounded,
  });

  /// e.g. "Waiter sign in". Staff share a building and sometimes a device pile;
  /// naming the app on its own sign-in screen is how someone knows they picked
  /// up the right tablet.
  final String title;

  final IconData icon;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    // Staff sign in on the same till every shift; pre-filling the address they
    // used last saves typing on a device with a cramped keyboard.
    _email = TextEditingController(text: ref.read(sessionProvider).lastEmail);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref.read(authControllerProvider.notifier).signIn(
          email: _email.text,
          password: _password.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);
    final env = Environment.current;
    final text = strings(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              // Keeps the form readable on a 10" tablet instead of stretching
              // the fields the full width of the screen.
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                // Lets the platform's password manager fill both fields and
                // commit them together. Staff sign in on a shared till several
                // times a shift; a manager rolling a password should not mean
                // everyone types it by hand.
                child: AutofillGroup(
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primaryContainer,
                        ),
                        child: Icon(
                          widget.icon,
                          size: 44,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      widget.title,
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    if (!env.isProduction) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Center(
                        child: Chip(
                          label: Text(env.label),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: theme.colorScheme.tertiaryContainer,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                    TextFormField(
                      controller: _email,
                      autocorrect: false,
                      enabled: !auth.isBusy,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.none,
                      autofillHints: const [AutofillHints.username],
                      decoration: InputDecoration(
                        labelText: text.signInEmail,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? text.signInEmailMissing
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      enabled: !auth.isBusy,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: text.signInPassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          // Screen readers need this; the icon alone says nothing.
                          tooltip: _obscure
                              ? text.signInShowPassword
                              : text.signInHidePassword,
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? text.signInPasswordMissing
                          : null,
                    ),
                    if (auth.error != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      AppNotice(
                        tone: NoticeTone.danger,
                        title: strings(context).errorRejectedTitle,
                        message: auth.error!.message,
                        margin: EdgeInsets.zero,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      height: AppSizes.primaryActionHeight,
                      child: FilledButton(
                        onPressed: auth.isBusy ? null : _submit,
                        child: auth.isBusy
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(text.signIn),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextButton.icon(
                      onPressed: auth.isBusy
                          ? null
                          : () => ServerSettingsSheet.show(context),
                      icon: const Icon(Icons.dns_outlined),
                      label: Text(text.serverSettings),
                    ),
                  ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

