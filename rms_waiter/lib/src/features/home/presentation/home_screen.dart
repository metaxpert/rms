import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/providers.dart';
import '../../authentication/application/auth_controller.dart';
import '../../branches/data/branch_repository.dart';

/// Signed-in shell.
///
/// Currently shows session context and the actions that exist today. The floor
/// plan, menu and cart land in later phases — this deliberately does NOT render
/// placeholder tables or fake orders, because a screen that looks finished but
/// does nothing is how staff learn to distrust an app (brief §42).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider);
    final branches = ref.watch(branchesProvider);

    final branchName = branches.maybeWhen(
      data: (list) {
        for (final b in list) {
          if (b.id == session.branchId) return b.name;
        }
        return null;
      },
      orElse: () => null,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Floor'),
        actions: [
          IconButton(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).clearBranch(),
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: 'Switch outlet',
          ),
          IconButton(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.storefront_rounded,
                            color: theme.colorScheme.primary),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            branchName ?? 'Outlet selected',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Signed in',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    Text(
                      session.lastEmail ?? '—',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Center(
              child: Column(
                children: [
                  Icon(Icons.table_restaurant_outlined,
                      size: 56, color: theme.colorScheme.outline),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Floor plan is not built yet',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Tables, menu and ordering arrive in the next phases.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
