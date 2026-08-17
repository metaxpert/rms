import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rms_core/rms_core.dart';

import '../../../l10n/app_text.dart';
import '../application/geofence.dart';
import '../data/route_service.dart';
import '../data/tracking_repository.dart';
import 'delivery_map.dart';

/// The live map, its ETA, and the honest state of the feed behind it.
///
/// Everything that can be unknown here has a state of its own, because on a phone
/// on Pakistani mobile data every one of them happens: the rider has not started
/// sharing, the position is minutes old, the socket is retrying, the read failed
/// and there is nothing yet to show. The one thing this never does is draw a
/// confident marker it cannot justify.
class LiveTracking extends ConsumerStatefulWidget {
  const LiveTracking({super.key, required this.deliveryId});

  final String deliveryId;

  @override
  ConsumerState<LiveTracking> createState() => _LiveTrackingState();
}

class _LiveTrackingState extends ConsumerState<LiveTracking> {
  /// The camera follows the rider until the customer pans, and again when they
  /// press Recentre.
  bool _follow = true;

  RoutePlan? _route;

  /// Guards the route request, so a rebuild does not queue a second one behind the
  /// first. The service throttles too; this is the cheaper gate in front of it.
  bool _routing = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trackingControllerProvider(widget.deliveryId));
    final text = appText(context);
    final theme = Theme.of(context);

    // Alerts are raised from here rather than from the controller because the copy
    // has to be localised, and a controller has no BuildContext to translate with.
    // The dedupe ledger makes this safe to call on every build.
    _raiseAlerts(state);
    _refreshRoute(state);

    if (state.isLoading && state.tracking == null) {
      return const _MapFrame(child: LoadingView());
    }

    final error = state.error;
    if (error != null && state.tracking == null) {
      return _MapFrame(
        child: ErrorView(
          error: error,
          onRetry: () => ref
              .read(trackingControllerProvider(widget.deliveryId).notifier)
              .refresh(),
        ),
      );
    }

    final tracking = state.tracking;
    if (tracking == null) return const SizedBox.shrink();

    // Nothing to draw a rider with. A real and common state — a job assigned but
    // not yet collected — so it is stated rather than filled with a marker at a
    // guessed position.
    if (!tracking.hasPosition) {
      return AppNotice(
        icon: Icons.satellite_alt_outlined,
        title: text.trackNoPositionYet,
        margin: EdgeInsets.zero,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: SizedBox(
            height: 260,
            child: Stack(
              children: [
                DeliveryMap(
                  tracking: tracking,
                  route: _route,
                  trail: state.trail,
                  follow: _follow,
                  onFollowChanged: (follow) {
                    if (follow != _follow) setState(() => _follow = follow);
                  },
                ),
                // The feed's own state, over the map rather than beside it: a
                // customer looking at a marker needs to know in the same glance
                // whether to believe it.
                PositionedDirectional(
                  top: AppSpacing.sm,
                  start: AppSpacing.sm,
                  child: _FeedChip(
                    live: state.isLive,
                    stale: tracking.position?.stale ?? false,
                    at: tracking.position?.at,
                  ),
                ),
                if (!_follow)
                  PositionedDirectional(
                    bottom: AppSpacing.sm,
                    end: AppSpacing.sm,
                    child: FilledButton.icon(
                      onPressed: () => setState(() => _follow = true),
                      icon: const Icon(Icons.my_location_rounded, size: 18),
                      label: Text(text.mapRecenter),
                      style: FilledButton.styleFrom(
                        // Smaller than a primary action: this is a map control, not
                        // the thing the screen is for.
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        textStyle: theme.textTheme.labelMedium,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _Distance(tracking: tracking, route: _route),
      ],
    );
  }

  /// Ask for a route when the rider has moved enough to need a new one.
  ///
  /// The throttling lives in the service — cache, distance and time thresholds,
  /// single-flight — so this only has to avoid starting a second request while one
  /// is out, and avoid asking at all when there is nothing to route between.
  void _refreshRoute(TrackingState state) {
    final tracking = state.tracking;
    final position = tracking?.position;
    final destination = tracking?.destination;
    if (position == null || destination == null || _routing) return;
    if (tracking!.isFinished) return;

    _routing = true;
    unawaited(
      ref
          .read(routeServiceProvider)
          .route(
            from: TrackedPlace(lat: position.lat, lng: position.lng),
            to: destination,
          )
          .then((plan) {
        if (!mounted) return;
        _routing = false;
        if (plan != null) setState(() => _route = plan);
      }).catchError((_) {
        _routing = false;
      }),
    );
  }

  void _raiseAlerts(TrackingState state) {
    final tracking = state.tracking;
    if (tracking == null) return;

    final text = appText(context);
    final alerts = ref.read(deliveryAlertsProvider);

    for (final alert in alertsFor(tracking)) {
      final body = switch (alert) {
        DeliveryAlert.nearby => text.alertNearby,
        DeliveryAlert.almostThere => text.alertAlmostThere,
        DeliveryAlert.arrived => text.alertArrived,
        // The lifecycle alerts reuse the wording the tracker already shows for the
        // same moment, so a notification and the screen behind it never disagree
        // about what happened.
        _ => null,
      };
      if (body == null) continue;

      unawaited(alerts.raise(
        deliveryId: tracking.deliveryId,
        alert: alert,
        title: text.yourOrder,
        body: body,
      ));
    }
  }
}

/// A fixed-height well, so loading, error and map states are all the same size.
///
/// Without it the card grows when the map lands and the page jumps under a thumb —
/// which is the re-assembly a skeleton exists to prevent.
class _MapFrame extends StatelessWidget {
  const _MapFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          height: 260,
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.5),
          child: child,
        ),
      );
}

/// Whether to believe the marker.
class _FeedChip extends StatelessWidget {
  const _FeedChip({required this.live, required this.stale, this.at});

  final bool live;
  final bool stale;
  final DateTime? at;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = appText(context);

    // Stale beats live. A socket that is connected while the rider's phone has
    // stopped reporting is still a frozen marker, and saying "Live" over it would
    // be the most misleading thing on the screen.
    final (label, colour, icon) = stale
        ? (
            at == null
                ? text.trackStale
                : text.trackLastSeen(DateFormat.Hm().format(at!)),
            AppStatusColors.preparing,
            Icons.cloud_off_rounded,
          )
        : live
            ? (text.trackLive, AppStatusColors.available, Icons.circle)
            : (text.trackStale, AppStatusColors.settled, Icons.sync_rounded);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        // Opaque, not tinted: this sits on map tiles, and a translucent chip over a
        // photograph of a city is unreadable half the time.
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppElevation.resting(theme.brightness),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: icon == Icons.circle ? 9 : 14,
              color: context.statusText(colour)),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: context.statusText(colour)),
          ),
        ],
      ),
    );
  }
}

/// How far, and how long.
class _Distance extends StatelessWidget {
  const _Distance({required this.tracking, this.route});

  final DeliveryTracking tracking;
  final RoutePlan? route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = appText(context);

    final plan = route;
    final metres = plan?.metres ?? remainingMetres(tracking);
    // The route's own estimate first; the restaurant's dispatch figure as the
    // fallback. A live estimate from the rider's actual position beats one set
    // before they left.
    final minutes = plan?.etaMinutes ?? tracking.etaMinutes;

    if (metres == null && minutes == null) return const SizedBox.shrink();

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (minutes != null)
          Text(
            text.trackEta(minutes),
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        if (metres != null)
          Text(
            text.trackDistance((metres / 1000).toStringAsFixed(1)),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        // Said out loud when the line on the map is a straight one. A dashed line
        // across a river with a confident "6 min" on it is a promise the app cannot
        // keep.
        if (plan != null && !plan.isRoad)
          Text(
            text.trackRouteEstimated,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
      ],
    );
  }
}
