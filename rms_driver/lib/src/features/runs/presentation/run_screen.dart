import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:rms_core/rms_core.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text(delivery?.deliveryNo ?? 'Run')),
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
            onRefresh: () async => ref.invalidate(deliveryProvider(delivery.id)),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _Header(delivery: delivery),
                const SizedBox(height: AppSpacing.lg),
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

class _Header extends StatelessWidget {
  const _Header({required this.delivery});

  final Delivery delivery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                delivery.orderNo.isEmpty ? delivery.deliveryNo : delivery.orderNo,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                [
                  delivery.provider,
                  if (delivery.etaMinutes != null)
                    'ETA ${delivery.etaMinutes} min',
                ].join(' · '),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        StatusBadge(
          label: delivery.status.label,
          color: delivery.status.color,
          icon: delivery.status.icon,
        ),
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
    final address = delivery.address;
    final location = delivery.location;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on_rounded,
                    color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Text('Drop-off', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SelectableText(
              address ?? 'No address on file — call the restaurant.',
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
                      Clipboard.setData(ClipboardData(
                          text: '${location.lat},${location.lng}'));
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(const SnackBar(
                          content: Text('Coordinates copied — paste into Maps.'),
                        ));
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy'),
                  ),
                ],
              ),
            ],
          ],
        ),
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
                      ? AppStatusColors.ready
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    run.sharing ? 'Sharing your location' : 'Location off',
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
              run.sharing
                  ? 'The customer can see roughly where you are. It stops when '
                      'the run finishes.'
                  // Explicit rather than implied: a rider's whereabouts is the
                  // restaurant's business while they carry an order, and not
                  // otherwise.
                  : 'Turn on while you are carrying this order so the customer '
                      'can follow it.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (run.sharing && run.lastPingAt != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Last sent ${DateFormat.Hms().format(run.lastPingAt!)} '
                '· ${run.pingsSent} updates',
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
    final message = switch (problem) {
      LocationAvailability.serviceOff =>
        'Location is switched off on this phone. Turn it on in the pull-down '
            'settings, then try again.',
      LocationAvailability.denied =>
        'The app was not given permission this time. Tap the switch again to '
            'be asked once more.',
      LocationAvailability.blocked =>
        'Location permission is blocked for this app. It can only be turned '
            'back on in the phone\'s Settings → Apps.',
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
    final stamps = <(String, DateTime?)>[
      ('Assigned', delivery.assignedAt),
      ('Picked up', delivery.pickedUpAt),
      ('Delivered', delivery.deliveredAt),
    ].where((entry) => entry.$2 != null).toList();

    if (stamps.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Progress', style: theme.textTheme.titleSmall),
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              error.message,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
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
    final controller = ref.read(runControllerProvider(delivery.id).notifier);

    if (delivery.status.isTerminal) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(delivery.status.icon, color: delivery.status.color),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'This run is ${delivery.status.label.toLowerCase()}.',
                style: theme.textTheme.titleMedium,
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
            '${delivery.provider} is carrying this one. Track it through their '
            'app — nothing here changes it.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    final label = delivery.status.nextActionLabel;
    if (label == null) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            // PENDING: dispatch is a manager's permission, so a rider waiting
            // to be given the job is told that rather than shown a dead button.
            'Waiting for the restaurant to assign this run.',
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
                        final otp = await _askForOtp(context);
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
                  : () => _reportFailure(context, controller, delivery),
              icon: const Icon(Icons.report_gmailerrorred_rounded),
              label: const Text('Something went wrong'),
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
  Future<String?> _askForOtp(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm the handover'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ask the customer to read out the code on their order.'),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
              decoration: const InputDecoration(
                labelText: 'Delivery code',
                prefixIcon: Icon(Icons.password_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Delivered'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _reportFailure(
    BuildContext context,
    RunController controller,
    Delivery delivery,
  ) async {
    // The backend takes free text, but a rider at a door should be picking, not
    // typing. These are the reasons a run actually fails.
    const reasons = [
      'Nobody at the address',
      'Customer refused the order',
      'Address could not be found',
      'Customer would not give the code',
      'Accident or vehicle problem',
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
                'What happened?',
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark this run failed?'),
        content: Text(
          '"$reason"\n\nThe restaurant is told straight away. This cannot be '
          'undone from here.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Mark failed'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await controller.markFailed(delivery, reason);
  }
}
