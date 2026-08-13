import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:rms_core/rms_core.dart';
import '../../../l10n/app_text.dart';
import '../data/service_repository.dart';
import 'dashboard_view.dart';
import 'kitchen_view.dart';
import 'sales_view.dart';

/// The manager's whole app: three views of one moment in the service.
///
/// One snapshot feeds all three, so the tabs cannot disagree with each other —
/// and crossing between them costs nothing, which matters on a phone being
/// glanced at between two other jobs.
class ManagerShell extends ConsumerStatefulWidget {
  const ManagerShell({super.key});

  @override
  ConsumerState<ManagerShell> createState() => _ManagerShellState();
}

class _ManagerShellState extends ConsumerState<ManagerShell> {
  int _tab = 0;



  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(serviceSnapshotProvider);
    final text = appText(context);
    final titles = [text.tabService, text.tabKitchen, text.tabSales];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(titles[_tab]),
            const _OutletLabel(),
          ],
        ),
        actions: [
          const _LiveDot(),
          const _OutletMenu(),
          IconButton(
            onPressed: () => ref.invalidate(serviceSnapshotProvider),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: text.refresh,
          ),
          IconButton(
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout_rounded),
            tooltip: text.signOut,
          ),
        ],
      ),
      body: snapshot.when(
        loading: () => LoadingView(message: text.readingService),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(serviceSnapshotProvider),
        ),
        data: (snapshot) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(serviceSnapshotProvider),
          child: switch (_tab) {
            1 => KitchenView(snapshot: snapshot),
            2 => SalesView(snapshot: snapshot),
            _ => DashboardView(snapshot: snapshot),
          },
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard_rounded),
            label: text.tabService,
          ),
          NavigationDestination(
            icon: const Icon(Icons.soup_kitchen_outlined),
            selectedIcon: const Icon(Icons.soup_kitchen_rounded),
            label: text.tabKitchen,
          ),
          NavigationDestination(
            icon: const Icon(Icons.payments_outlined),
            selectedIcon: const Icon(Icons.payments_rounded),
            label: text.tabSales,
          ),
        ],
      ),
    );
  }
}

/// Which outlet the numbers are for. Always shown, because the same dashboard
/// means very different things for one branch and for a whole chain.
class _OutletLabel extends ConsumerWidget {
  const _OutletLabel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchId = ref.watch(sessionProvider).branchId;
    final branches = ref.watch(branchesProvider).valueOrNull;

    final text = appText(context);
    final name = branchId == null
        ? text.allOutlets
        : branches
                ?.where((b) => b.id == branchId)
                .map((b) => b.name)
                .firstOrNull ??
            text.oneOutlet;

    return Text(
      name,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
    );
  }
}

class _OutletMenu extends ConsumerWidget {
  const _OutletMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(branchesProvider).valueOrNull ?? const [];
    final current = ref.watch(sessionProvider).branchId;
    final auth = ref.read(authControllerProvider.notifier);

    return PopupMenuButton<String?>(
      icon: const Icon(Icons.store_mall_directory_outlined),
      tooltip: appText(context).chooseOutlet,
      onSelected: (id) async {
        // Unlike the waiter and driver apps, an outlet here is a filter and not
        // a gate — comparing outlets is the manager's job.
        if (id == null) {
          await auth.clearBranch();
        } else {
          await auth.selectBranch(id);
        }
        ref.invalidate(serviceSnapshotProvider);
      },
      itemBuilder: (context) => [
        CheckedPopupMenuItem<String?>(
          checked: current == null,
          child: Text(appText(context).allOutlets),
        ),
        for (final branch in branches)
          CheckedPopupMenuItem<String?>(
            value: branch.id,
            checked: current == branch.id,
            child: Text(branch.name),
          ),
      ],
    );
  }
}

/// Whether the numbers on screen are being kept current.
///
/// A dashboard that might be minutes stale and does not say so is worse than
/// one that admits it: a manager walks to the kitchen on the strength of these
/// figures.
class _LiveDot extends ConsumerWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status =
        ref.watch(realtimeStatusProvider).valueOrNull ?? RealtimeStatus.idle;
    final takenAt = ref.watch(serviceSnapshotProvider).valueOrNull?.takenAt;
    final live = status == RealtimeStatus.live;
    final text = appText(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Tooltip(
        message: live
            ? (takenAt == null
                ? text.liveTooltipJustNow
                : text.liveTooltip(DateFormat.Hms().format(takenAt)))
            : text.offlineTooltip,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              live ? Icons.circle : Icons.cloud_off_rounded,
              size: live ? 10 : 16,
              color: live
                  ? AppStatusColors.available
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              live ? text.live : text.offline,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
