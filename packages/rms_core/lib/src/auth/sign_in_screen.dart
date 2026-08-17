import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/environment.dart';
import '../providers.dart';
import '../l10n/strings.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/app_surfaces.dart';
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

    // The brand panel behind the form. On a phone it is a band across the top
    // that the card overlaps; on a tablet in landscape it is the left half of
    // the screen, because a 420-pixel form floating in the middle of a 1200-
    // pixel void is the thing that made this screen look like a dialog box.
    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.medium;

    // Not `onPrimary`: on a dark scheme the hero gradient is built from
    // `primaryContainer`, so its ink is `onPrimaryContainer`. See
    // AppGradients.hero.
    final brandInk = AppGradients.ink(theme.colorScheme);

    final brand = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        AppBrandMark(icon: widget.icon, size: wide ? 88 : 64),
        const SizedBox(height: AppSpacing.lg),
        Text(
          widget.title,
          style: (wide
                  ? theme.textTheme.headlineLarge
                  : theme.textTheme.headlineSmall)
              ?.copyWith(color: brandInk),
          textAlign: wide ? TextAlign.start : TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          text.signInBlurb,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: brandInk.withValues(alpha: 0.82),
          ),
          textAlign: wide ? TextAlign.start : TextAlign.center,
        ),
        if (!env.isProduction) ...[
          const SizedBox(height: AppSpacing.md),
          // Against the gradient now, so it needs its own contrast rather than
          // the tertiary container's — which was tuned for a neutral surface.
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: brandInk.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: brandInk.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              env.label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: brandInk,
              ),
            ),
          ),
        ],
      ],
    );

    final form = Form(
      key: _formKey,
      // Lets the platform's password manager fill both fields and
      // commit them together. Staff sign in on a shared till several
      // times a shift; a manager rolling a password should not mean
      // everyone types it by hand.
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text.signInHeading, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xl),
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
              validator: (v) =>
                  (v == null || v.isEmpty) ? text.signInPasswordMissing : null,
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
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          // The default takes the primary, which on a
                          // disabled filled button is a spinner the
                          // same colour as the surface under it.
                          color: brandInk,
                        ),
                      )
                    : Text(text.signIn),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed:
                  auth.isBusy ? null : () => ServerSettingsSheet.show(context),
              icon: const Icon(Icons.dns_outlined),
              label: Text(text.serverSettings),
            ),
          ],
        ),
      ),
    );

    // The form sits on a card, and the card overlaps the brand panel. Two
    // stacked rectangles read as two screens; an overlap reads as one.
    final card = ConstrainedBox(
      // Keeps the form readable on a 10" tablet instead of stretching the
      // fields the full width of the screen.
      constraints: const BoxConstraints(maxWidth: 460),
      child: AppCard(
        raised: true,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: form,
      ),
    );

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppGradients.hero(theme.colorScheme),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [brand],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: card,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      // The gradient runs behind the status bar; the scroll view keeps the form
      // clear of the keyboard when it comes up on a phone.
      body: DecoratedBox(
        decoration:
            BoxDecoration(gradient: AppGradients.hero(theme.colorScheme)),
        child: SingleChildScrollView(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xxl,
                    AppSpacing.xl,
                    AppSpacing.xl,
                  ),
                  child: brand,
                ),
                Container(
                  width: double.infinity,
                  // Fills whatever is left below the card so the gradient does
                  // not reappear under it on a tall screen.
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.sizeOf(context).height * 0.55,
                  ),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.xxl),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  child: Center(child: card),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
