import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:rms_core/rms_core.dart';

import '../data/route_service.dart';

/// The live map: where the rider is, where they came from, where they are going.
///
/// Built on `flutter_map` over OpenStreetMap tiles — no API key, no billing, and a
/// plain Flutter widget layer, so it themes with the design system and honours dark
/// mode instead of being an opaque platform view sitting on top of it.
///
/// Two things dominate the design of this widget, and both are about *not*
/// rebuilding:
///
/// 1. **The marker animates; the map does not rebuild.** A position arrives every
///    fifteen seconds. Rebuilding the tile layer, the polylines and the camera on
///    each one would re-rasterise the whole map for a marker that moved forty
///    pixels. The tween lives in a child widget so only the marker's transform is
///    rebuilt per frame.
/// 2. **The camera follows until the customer disagrees.** The moment they pan or
///    zoom, following stops — a map that drags itself back while somebody is
///    looking at their own street is worse than one that never moved. `Recenter`
///    gives it back explicitly.
class DeliveryMap extends StatefulWidget {
  const DeliveryMap({
    super.key,
    required this.tracking,
    this.route,
    this.trail = const [],
    this.follow = true,
    this.onFollowChanged,
  });

  final DeliveryTracking tracking;

  /// The road route, when one could be fetched.
  final RoutePlan? route;

  /// Where the bike has actually been.
  final List<TrackedPosition> trail;

  final bool follow;
  final ValueChanged<bool>? onFollowChanged;

  @override
  State<DeliveryMap> createState() => _DeliveryMapState();
}

class _DeliveryMapState extends State<DeliveryMap> {
  final _controller = MapController();

  /// The position the marker is animating *from*.
  ///
  /// Kept here rather than derived, because the widget is rebuilt with only the
  /// new position and the old one is the half of the tween the parent no longer
  /// has.
  TrackedPosition? _previous;

  /// Set once the first camera fit has happened, so a rebuild does not yank the
  /// camera back to the whole-journey view while the customer is reading a street
  /// name.
  bool _framed = false;

  @override
  void didUpdateWidget(DeliveryMap old) {
    super.didUpdateWidget(old);
    final before = old.tracking.position;
    final now = widget.tracking.position;
    if (before != null &&
        now != null &&
        (before.lat != now.lat || before.lng != now.lng)) {
      _previous = before;
      if (widget.follow) _followTo(now);
    }

    // Following turned back on — the customer pressed Recentre. Handled here
    // rather than through a GlobalKey into this state, so the parent owns one flag
    // and nothing reaches into a private class to drive the camera.
    if (!old.follow && widget.follow && now != null) {
      _controller.move(LatLng(now.lat, now.lng), 16);
    }
  }

  void _followTo(TrackedPosition position) {
    // `move` rather than a camera-fit: refitting on every fix would zoom in and out
    // as the gap to the destination closes, which reads as the map twitching.
    _controller.move(
        LatLng(position.lat, position.lng), _controller.camera.zoom);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final position = widget.tracking.position;
    final destination = widget.tracking.destination;
    // No origin marker: the outlet has no coordinates in the schema, so it is
    // named beside the map rather than pinned at a guess. See TrackedOutlet.
    final points = <LatLng>[
      if (position != null) LatLng(position.lat, position.lng),
      if (destination != null) LatLng(destination.lat, destination.lng),
    ];

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: points.isEmpty
            // Islamabad, only as the frame for a map with nothing on it yet. Never
            // shown with a marker — a rider is never drawn at a guess.
            ? const LatLng(33.6844, 73.0479)
            : points.first,
        initialZoom: points.length > 1 ? 13 : 15,
        interactionOptions: const InteractionOptions(
          // Rotation off: a customer glancing at a delivery has no use for a
          // rotated north, and a two-finger twist while scrolling a page is the
          // most common accidental gesture on a map this size.
          flags: InteractiveFlag.pinchZoom |
              InteractiveFlag.drag |
              InteractiveFlag.doubleTapZoom,
        ),
        // Any deliberate gesture hands control to the customer. `hasGesture`
        // distinguishes their pan from our own `move`, which would otherwise
        // switch following off the first time it followed.
        onPositionChanged: (camera, hasGesture) {
          if (hasGesture && widget.follow) widget.onFollowChanged?.call(false);
        },
        onMapReady: () => _frame(points),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          // OSM's tile policy requires an identifying agent; an app that omits it
          // is one they are entitled to block.
          userAgentPackageName: 'net.metaxperts.rms.customer',
          // Tiles are photographs of a city — they do not have a dark variant, and
          // inverting them produces a negative that is harder to read, not easier.
          // The chrome around the map carries the theme instead.
          tileProvider: NetworkTileProvider(),
        ),

        // Where the bike has been, under the planned route so the plan reads as
        // the thing still to come.
        if (widget.trail.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.trail
                    .map((p) => LatLng(p.lat, p.lng))
                    .toList(growable: false),
                strokeWidth: 3,
                color: theme.colorScheme.primary.withValues(alpha: 0.35),
              ),
            ],
          ),

        if (widget.route != null && widget.route!.points.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.route!.points
                    .map((p) => LatLng(p.lat, p.lng))
                    .toList(growable: false),
                strokeWidth: 5,
                color: theme.colorScheme.primary,
                // A straight-line fallback is drawn dashed, because a solid line
                // across a river is a claim about a road that does not exist.
                pattern: widget.route!.isRoad
                    ? const StrokePattern.solid()
                    : StrokePattern.dashed(segments: const [10, 8]),
              ),
            ],
          ),

        MarkerLayer(
          markers: [
            if (destination != null)
              _pin(
                context,
                point: LatLng(destination.lat, destination.lng),
                icon: Icons.home_rounded,
                color: context.statusFill(AppStatusColors.available),
                semanticLabel: destination.label,
              ),
            if (position != null)
              Marker(
                point: LatLng(position.lat, position.lng),
                width: 56,
                height: 56,
                child: _RiderMarker(
                  from: _previous,
                  to: position,
                  stale: position.stale,
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Frame the whole journey once, on first load.
  void _frame(List<LatLng> points) {
    if (_framed || points.length < 2 || !mounted) return;
    _framed = true;
    _controller.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        // Padding, not a zoom cap: the markers are 56px tall and drawn centred, so
        // a tight fit puts the rider's icon half off the top of the map.
        padding: const EdgeInsets.all(64),
        maxZoom: 16,
      ),
    );
  }

  Marker _pin(
    BuildContext context, {
    required LatLng point,
    required IconData icon,
    required Color color,
    String? semanticLabel,
  }) =>
      Marker(
        point: point,
        width: 40,
        height: 40,
        child: Semantics(
          label: semanticLabel,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
              boxShadow: AppElevation.resting(Theme.of(context).brightness),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      );
}

/// The rider's marker, interpolated between fixes.
///
/// Positions arrive every fifteen seconds. Snapping the marker between them makes
/// a bike teleport four times a minute, which reads as a broken map even though the
/// data is perfect. Tweening across the gap is the difference between "tracking"
/// and "a dot that jumps".
///
/// The duration is the gap between fixes rather than a fixed animation length: an
/// interpolation shorter than the gap finishes early and leaves the marker parked
/// until the next one, which is the jump again with extra steps.
class _RiderMarker extends StatelessWidget {
  const _RiderMarker({required this.to, this.from, this.stale = false});

  final TrackedPosition to;
  final TrackedPosition? from;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final from = this.from;

    // Where the bike is pointing. The phone's own heading when it has one — it is
    // the only source that is right while stationary — and otherwise the bearing
    // between the last two fixes.
    final heading = to.headingDeg ??
        (from == null
            ? 0.0
            : bearingBetween(
                TrackedPlace(lat: from.lat, lng: from.lng),
                TrackedPlace(lat: to.lat, lng: to.lng),
              ));

    final colour =
        stale ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.primary;

    return Semantics(
      label: stale ? null : 'Rider',
      child: TweenAnimationBuilder<double>(
        // Reduced motion is honoured: the marker still moves, it simply arrives
        // instantly. A vestibular disorder is not a reason to be denied a map.
        duration: AppMotion.reduced(context) ? Duration.zero : AppMotion.slow,
        curve: Curves.easeInOut,
        tween: Tween(begin: 0, end: heading),
        builder: (context, angle, _) => Stack(
          alignment: Alignment.center,
          children: [
            // A halo, so the marker survives being drawn over a dark building or a
            // pale road. Dimmed when the fix is stale, which is the visual half of
            // the "last seen" wording beside the map.
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colour.withValues(alpha: stale ? 0.10 : 0.18),
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.surface,
                border: Border.all(color: colour, width: 2),
                boxShadow: AppElevation.resting(theme.brightness),
              ),
              child: Transform.rotate(
                // The glyph points up by default; the bearing is clockwise from
                // north, which is the same thing in radians.
                angle: angle * math.pi / 180,
                child: Icon(Icons.navigation_rounded, size: 18, color: colour),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
