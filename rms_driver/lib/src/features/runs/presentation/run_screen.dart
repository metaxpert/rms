import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:rms_core/rms_core.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_text.dart';
import '../../location/data/location_source.dart';
import '../application/run_controller.dart';
import '../data/delivery_repository.dart';

/// One run, from the pass to the door.
///
/// The whole screen is built around a single large action, because a rider
/// reads it one-handed, outdoors, often in a hurry. What that action IS comes
/// from the job's status, so the button and the request it sends can never
/// disagree.
class RunScreen extends ConsumerWidget {
  const RunScreen({super.key, required this.deliveryId});

  final String deliveryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(deliveryProvider(deliveryId));
    final run = ref.watch(runControllerProvider(deliveryId));

    // What the controller last saw beats a fetch that may be in flight behind it.
    final delivery = run.delivery ?? async.valueOrNull;

    final text = appText(context);

    return HeroScaffold(
      header: AppHeroHeader(
        // The order number, which is what a customer at a door and a manager on
        // the phone both quote. It was the app bar's title as `deliveryNo`, an
        // internal number nobody outside this screen uses.
        title: delivery == null
            ? text.run
            : (delivery.orderNo.isEmpty
                ? delivery.deliveryNo
                : delivery.orderNo),
        subtitle: delivery == null
            ? null
            : [
                delivery.provider,
                if (delivery.etaMinutes != null)
                  text.etaMinutes(delivery.etaMinutes!),
              ].join(' · '),
        leading: HeroIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: text.runsTitle,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      overlap: AppSpacing.md,
      body: delivery == null
          ? async.when(
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(deliveryProvider(deliveryId)),
              ),
              data: (_) => const SizedBox.shrink(),
            )
          : _RunBody(delivery: delivery, run: run),
    );
  }
}

class _RunBody extends ConsumerWidget {
  const _RunBody({required this.delivery, required this.run});

  final Delivery delivery;
  final RunState run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(runControllerProvider(delivery.id).notifier);

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(deliveryProvider(delivery.id)),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                // The order number, provider and ETA that used to head this list
                // are in the hero header now. What is left is the state of the
                // run, and that belongs on the card about the drop-off rather
                // than floating above it.
                _DropOffCard(delivery: delivery),
                const SizedBox(height: AppSpacing.lg),
                if (delivery.isOwnFleet && !delivery.status.isTerminal)
                  _SharingCard(
                    run: run,
                    onStart: controller.startSharing,
                    onStop: controller.stopSharing,
                  ),
                if (run.error != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _ErrorNote(error: run.error!),
                ],
                const SizedBox(height: AppSpacing.lg),
                _Timeline(delivery: delivery),
              ],
            ),
          ),
        ),
        _ActionBar(delivery: delivery, run: run),
      ],
    );
  }
}

class _DropOffCard extends StatelessWidget {
  const _DropOffCard({required this.delivery});

  final Delivery delivery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = appText(context);
    final address = delivery.address;
    final location = delivery.location;

    return AppCard(
      // The run's state, carried by the card that says where it is going. The
      // rail is the fastest read on the screen and the badge beside the heading
      // is the one that survives a rider who cannot see colour.
      accent: delivery.status.color,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg + AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(text.dropOff, style: theme.textTheme.titleMedium),
              ),
              StatusBadge(
                label: delivery.status.labelIn(strings(context)),
                color: delivery.status.color,
                icon: delivery.status.icon,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SelectableText(
            address ?? text.noAddressCall,
            style: theme.textTheme.bodyLarge,
          ),
          if (location != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(Icons.my_location_rounded,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '${location.lat.toStringAsFixed(5)}, '
                    '${location.lng.toStringAsFixed(5)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                TextButton.icon(
                  // No map SDK is bundled: copying the coordinates hands them
                  // to whichever navigation app the rider already uses, which
                  // is the one they trust in their own city.
                  onPressed: () {
                    Clipboard.setData(
                        ClipboardData(text: '${location.lat},${location.lng}'));
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(SnackBar(
                        content: Text(text.coordinatesCopied),
                      ));
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text(text.copy),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Location sharing, with the rider's hand on the switch.
class _SharingCard extends StatelessWidget {
  const _SharingCard({
    required this.run,
    required this.onStart,
    required this.onStop,
  });

  final RunState run;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = appText(context);
    final problem = run.locationProblem;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  run.sharing
                      ? Icons.share_location_rounded
                      : Icons.location_disabled_rounded,
                  color: run.sharing
                      ? context.statusText(AppStatusColors.ready)
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    run.sharing ? text.sharingLocation : text.locationOff,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Switch(
                  value: run.sharing,
                  onChanged: (on) => on ? onStart() : onStop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              // Explicit rather than implied: a rider's whereabouts is the
              // restaurant's business while they carry an order, and not
              // otherwise.
              run.sharing ? text.sharingOnHint : text.sharingOffHint,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (run.sharing && run.lastPingAt != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                text.lastSent(
                    DateFormat.Hms().format(run.lastPingAt!), run.pingsSent),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
            if (problem != null) ...[
              const SizedBox(height: AppSpacing.md),
              _LocationProblem(problem: problem),
            ],
          ],
        ),
      ),
    );
  }
}

class _LocationProblem extends StatelessWidget {
  const _LocationProblem({required this.problem});

  final LocationAvailability problem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Each of these has a different remedy, and a rider on a bike has no
    // patience for a generic "location unavailable".
    final text = appText(context);
    final message = switch (problem) {
      LocationAvailability.serviceOff => text.locationServiceOff,
      LocationAvailability.denied => text.locationDenied,
      LocationAvailability.blocked => text.locationBlocked,
      // Tracking is working, just not with the phone in a pocket — which is most
      // of a run. Worth saying rather than leaving a customer to notice a marker
      // that stopped moving.
      LocationAvailability.foregroundOnly => text.locationForegroundOnly,
      LocationAvailability.ready => '',
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber_rounded,
            size: 18, color: theme.colorScheme.error),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(message, style: theme.textTheme.bodySmall),
        ),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.delivery});

  final Delivery delivery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = appText(context);
    final stamps = <(String, DateTime?)>[
      (text.progressAssigned, delivery.assignedAt),
      (text.progressPickedUp, delivery.pickedUpAt),
      (text.progressDelivered, delivery.deliveredAt),
    ].where((entry) => entry.$2 != null).toList();

    if (stamps.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text.progress, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        for (final (label, at) in stamps)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
                Text(
                  DateFormat.Hm().format(at!),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.error});

  final ApiException error;

  @override
  Widget build(BuildContext context) {
    return AppNotice(
      tone: NoticeTone.danger,
      title: strings(context).errorRejectedTitle,
      message: error.message,
      margin: EdgeInsets.zero,
    );
  }
}

/// One action, as large as the screen allows.
class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.delivery, required this.run});

  final Delivery delivery;
  final RunState run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final text = appText(context);
    final controller = ref.read(runControllerProvider(delivery.id).notifier);

    if (delivery.status.isTerminal) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                delivery.status.icon,
                color: context.statusFill(delivery.status.color),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Flexed, because it was not: "This run is delivered" at the 1.5x
              // text a rider is likely to have set ran 81 pixels off the right
              // of an entry-level phone, and the word it cut was the status.
              Flexible(
                child: Text(
                  text.runIsStatus(
                      delivery.status.labelIn(strings(context)).toLowerCase()),
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!delivery.isOwnFleet) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            text.aggregatorCarrying(delivery.provider),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    final label = delivery.status.nextActionLabelIn(strings(context));
    if (label == null) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            // PENDING: dispatch is a manager's permission, so a rider waiting
            // to be given the job is told that rather than shown a dead button.
            text.waitingForAssignment,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    final needsOtp = delivery.status == DeliveryStatus.enRoute;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              // Deliberately taller than the shared action height: this is
              // pressed with a thumb, wearing a glove, holding a bag.
              height: 64,
              child: FilledButton.icon(
                onPressed: run.isWorking
                    ? null
                    : () async {
                        if (!needsOtp) {
                          await controller.advance(delivery);
                          return;
                        }
                        final otp = await _askForOtp(context, text);
                        if (otp != null && otp.isNotEmpty) {
                          await controller.advance(delivery, otp: otp);
                        }
                      },
                icon: run.isWorking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(needsOtp
                        ? Icons.verified_outlined
                        : Icons.arrow_forward_rounded),
                label: Text(
                  label,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: run.isWorking
                  ? null
                  : () => _reportFailure(context, text, controller, delivery),
              icon: const Icon(Icons.report_gmailerrorred_rounded),
              label: Text(text.somethingWentWrong),
            ),
          ],
        ),
      ),
    );
  }

  /// The customer's code, read aloud at the door.
  ///
  /// The app never shows or stores it: the backend returns the code only when
  /// the delivery is created, so staff can pass it to the customer. A rider who
  /// could see it could close a job without arriving, which is the entire point
  /// of the check.
  Future<String?> _askForOtp(BuildContext context, AppText text) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(text.confirmHandover),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text.askForCode),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
              decoration: InputDecoration(
                labelText: text.deliveryCode,
                prefixIcon: const Icon(Icons.password_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(text.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(text.delivered),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _reportFailure(
    BuildContext context,
    AppText text,
    RunController controller,
    Delivery delivery,
  ) async {
    // The backend takes free text, but a rider at a door should be picking, not
    // typing. These are the reasons a run actually fails.
    final reasons = [
      text.failNobodyThere,
      text.failRefused,
      text.failAddressNotFound,
      text.failNoCode,
      text.failVehicle,
    ];

    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                text.whatHappened,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final reason in reasons)
              ListTile(
                title: Text(reason),
                onTap: () => Navigator.of(context).pop(reason),
              ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
    if (reason == null) return;
    if (!context.mounted) return;

    final confirmed = await confirmAction(
      context,
      title: text.markFailedTitle,
      message: text.markFailedMessage(reason),
      cancelLabel: text.goBack,
      confirmLabel: text.markFailed,
      // Ends the run and puts a customer's dinner back on the restaurant. The
      // error colour is the difference between a rider confirming and a rider
      // tapping the button on the right out of habit.
      isDestructive: true,
    );
    if (confirmed) await controller.markFailed(delivery, reason);
  }
}
