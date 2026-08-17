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

    return HeroScaffold(
      // Was an `AppBar` holding the tab name and the outlet in 12px under it.
      // That is a title bar: it spent the top strip of the screen on words the
      // manager already knew and gave the numbers below it nothing to sit
      // against. The gradient panel does the same job, says which of the four
      // apps this is, and gives the first row of tiles an edge to overlap.
      header: AppHeroHeader(
        title: titles[_tab],
        subtitle: _outletName(ref, context),
        trailing: const _LiveDot(),
        actions: [
          const _OutletMenu(),
          HeroIconButton(
            icon: Icons.refresh_rounded,
            tooltip: text.refresh,
            onPressed: () => ref.invalidate(serviceSnapshotProvider),
          ),
          HeroIconButton(
            icon: Icons.logout_rounded,
            tooltip: text.signOut,
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      // The body is pulled up into the header so the two read as one surface.
      // Only on the dashboard: the other two tabs are lists that start at the
      // top, and a list sliding under a panel it does not scroll behind is the
      // wrong kind of overlap.
      overlap: _tab == 0 ? AppSpacing.md : 0,
      body: snapshot.when(
        loading: () => LoadingView(
          message: text.readingService,
          skeleton: _ShellSkeleton(tab: _tab),
        ),
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

/// The shape of whichever tab is open, while the one read behind all three is
/// in flight.
///
/// Tab-aware rather than one generic placeholder: a manager who switches to
/// Sales and sees a grid of squares forming has been told the wrong thing about
/// what is coming, and the correction — squares replaced by rows — is exactly
/// the re-assembly a skeleton exists to avoid.
class _ShellSkeleton extends StatelessWidget {
  const _ShellSkeleton({required this.tab});

  final int tab;

  @override
  Widget build(BuildContext context) {
    if (tab == 0) {
      return SkeletonGroup(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              // The delegate the real grid uses, so the columns do not re-flow
              // the moment the data lands.
              gridDelegate: kpiGridDelegate,
              itemCount: 6,
              itemBuilder: (_, __) => const Skeleton.fill(),
            ),
          ],
        ),
      );
    }

    // Kitchen tickets and settled bills are both lists of cards; the row height
    // differs enough to be worth two numbers rather than one.
    return SkeletonList(rows: tab == 1 ? 4 : 7, rowHeight: tab == 1 ? 132 : 56);
  }
}

/// Which outlet the numbers are for. Always shown, because the same dashboard
/// means very different things for one branch and for a whole chain.
///
/// A function rather than the widget it used to be: the header takes its
/// subtitle as a string so it can style it against the gradient, and a widget
/// would have had to be told what colour to paint itself in.
String _outletName(WidgetRef ref, BuildContext context) {
  final branchId = ref.watch(sessionProvider).branchId;
  final branches = ref.watch(branchesProvider).valueOrNull;
  final text = appText(context);

  if (branchId == null) return text.allOutlets;
  return branches
          ?.where((b) => b.id == branchId)
          .map((b) => b.name)
          .firstOrNull ??
      text.oneOutlet;
}

class _OutletMenu extends ConsumerWidget {
  const _OutletMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(branchesProvider).valueOrNull ?? const [];
    final current = ref.watch(sessionProvider).branchId;
    final auth = ref.read(authControllerProvider.notifier);

    final ink = AppGradients.ink(Theme.of(context).colorScheme);

    return PopupMenuButton<String?>(
      // Against the gradient the app bar's `onSurfaceVariant` is a grey smear,
      // and the same translucent well the other header buttons use is what
      // makes this read as a control rather than as a glyph printed on it.
      icon: Container(
        width: AppSizes.chromeTouchTarget,
        height: AppSizes.chromeTouchTarget,
        decoration: BoxDecoration(
          color: ink.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.store_mall_directory_outlined,
          size: 22,
          color: ink,
        ),
      ),
      padding: EdgeInsets.zero,
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

    final theme = Theme.of(context);
    final ink = AppGradients.ink(theme.colorScheme);

    // On the gradient, so the status green that read well on a white app bar is
    // now a low-contrast smudge. The pill carries the meaning instead: a filled
    // dot and the word when live, a struck-through cloud and the word when not.
    // Colour is not doing the work either way, which is the rule.
    return Tooltip(
      message: live
          ? (takenAt == null
              ? text.liveTooltipJustNow
              : text.liveTooltip(DateFormat.Hms().format(takenAt)))
          : text.offlineTooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: ink.withValues(alpha: live ? 0.16 : 0.10),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: ink.withValues(alpha: live ? 0.4 : 0.24)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              live ? Icons.circle : Icons.cloud_off_rounded,
              size: live ? 9 : 14,
              color: ink,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              live ? text.live : text.offline,
              style: theme.textTheme.labelSmall?.copyWith(color: ink),
            ),
          ],
        ),
      ),
    );
  }
}
