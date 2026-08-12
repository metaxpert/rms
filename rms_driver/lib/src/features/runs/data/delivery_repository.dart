import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rms_core/rms_core.dart';

/// Every call the driver app makes against a delivery.
///
/// The state machine is the backend's — `PENDING → ASSIGNED → PICKED_UP →
/// EN_ROUTE → DELIVERED`, with `FAILED` from any live state — and each
/// transition is its own route. The app never invents a status; it asks for the
/// one transition the job's current status permits and lets the server refuse.
class DeliveryRepository {
  DeliveryRepository(this._client);

  final ApiClient _client;

  /// The outlet's delivery board.
  ///
  /// **Not scoped to the signed-in rider**, because no endpoint offers that: the
  /// list is branch-scoped and the JWT carries a user id, not the
  /// `driverEmployeeId` a job is assigned by. The app therefore shows the
  /// outlet's runs and says so, rather than filtering on a guess and hiding a
  /// job someone is waiting on.
  Future<List<Delivery>> runs() async {
    final data = await _client.get(_client.branchScoped('/restaurant/deliveries'));
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Delivery.fromJson)
        .toList(growable: false);
  }

  Future<Delivery> fetch(String id) async {
    final json = await _client.get('/restaurant/deliveries/$id');
    return Delivery.fromJson(json as Map<String, dynamic>);
  }

  /// Advance a job to its next state.
  ///
  /// The path comes from [DeliveryStatus.nextActionPath], so the app cannot ask
  /// for a transition the status does not allow — the button and the request
  /// are derived from the same source.
  ///
  /// The key is derived from the job and the step: a rider on a bad signal who
  /// taps "Picked up" twice must not get an error the second time, and a
  /// completion retried after a timeout must not be told the OTP was wrong when
  /// it was in fact accepted.
  Future<Delivery?> advance({
    required String id,
    required DeliveryStatus from,
    String? otp,
  }) async {
    final path = from.nextActionPath;
    if (path == null) return null;
    final response = await _client.post(
      '/restaurant/deliveries/$id/$path',
      {if (otp != null) 'otp': otp},
      'delivery:$id:$path${otp == null ? '' : ':$otp'}',
    );
    return _deliveryFrom(response);
  }

  Future<Delivery?> fail({required String id, required String reason}) async {
    final response = await _client.post(
      '/restaurant/deliveries/$id/fail',
      {'reason': reason},
      'delivery:$id:fail:${reason.hashCode}',
    );
    return _deliveryFrom(response);
  }

  /// Report where the rider is.
  ///
  /// Sent **unkeyed**: every ping is a distinct fact, not an operation to be
  /// replayed, and keying them would write one idempotency row per ping for a
  /// half-hour ride.
  Future<void> track({
    required String id,
    required double lat,
    required double lng,
    double? speedKph,
  }) =>
      _client.post(
        '/restaurant/deliveries/$id/track',
        {
          'geoLat': lat,
          'geoLng': lng,
          if (speedKph != null) 'speedKph': speedKph,
        },
        ApiClient.unkeyed,
      );

  static Delivery? _deliveryFrom(dynamic response) {
    if (response is! Map<String, dynamic> || response['id'] is! String) {
      return null;
    }
    try {
      return Delivery.fromJson(response);
    } on TypeError {
      return null;
    }
  }
}

final deliveryRepositoryProvider = Provider<DeliveryRepository>(
  (ref) => DeliveryRepository(ref.watch(apiClientProvider)),
);

/// The outlet's runs, split into what a rider still has to do and what is done.
@immutable
class RunBoard {
  const RunBoard({required this.active, required this.finished});

  /// Sorted so the job furthest along — the one with a customer waiting at a
  /// door — is at the top.
  final List<Delivery> active;
  final List<Delivery> finished;

  bool get isEmpty => active.isEmpty && finished.isEmpty;

  static RunBoard from(List<Delivery> deliveries) {
    final active = deliveries.where((d) => d.status.isActive).toList()
      ..sort((a, b) => _urgency(b).compareTo(_urgency(a)));
    final finished = deliveries.where((d) => d.status.isTerminal).toList()
      ..sort((a, b) => (b.deliveredAt ?? DateTime(0))
          .compareTo(a.deliveredAt ?? DateTime(0)));
    return RunBoard(active: active, finished: finished);
  }

  /// Later in the lifecycle means closer to a waiting customer.
  static int _urgency(Delivery delivery) => switch (delivery.status) {
        DeliveryStatus.enRoute => 3,
        DeliveryStatus.pickedUp => 2,
        DeliveryStatus.assigned => 1,
        _ => 0,
      };
}

final runBoardProvider = FutureProvider.autoDispose<RunBoard>(
  (ref) async => RunBoard.from(await ref.watch(deliveryRepositoryProvider).runs()),
);

/// One job, refetched whenever it is opened — a dispatcher may have reassigned
/// or cancelled it since the board was drawn.
final deliveryProvider = FutureProvider.autoDispose.family<Delivery, String>(
  (ref, id) => ref.watch(deliveryRepositoryProvider).fetch(id),
);
