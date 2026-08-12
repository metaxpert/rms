import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rms_core/rms_core.dart';
import '../../cart/application/cart_controller.dart';
import '../../orders/data/customer_order_repository.dart';

enum CheckoutStage { creating, addingItems, placing }

/// A checkout in flight, persisted.
///
/// The same reasoning as the waiter's send: placing an order is three calls,
/// and a phone can be locked, backgrounded or killed between any two of them. A
/// customer who taps "Place order", loses signal, and taps again must not be
/// charged for two dinners.
@immutable
class PendingCheckout {
  const PendingCheckout({
    required this.branchId,
    required this.key,
    required this.stage,
    required this.items,
    required this.channel,
    this.orderId,
    this.address,
  });

  final String branchId;

  /// Minted once and reused by every attempt, so a retry replays rather than
  /// repeats. Persisted, because the attempt that needs replaying is often the
  /// one that happened before the app was killed.
  final String key;

  final CheckoutStage stage;

  /// Frozen at the tap: the same key replayed with a different body is a 422.
  final List<Map<String, dynamic>> items;

  final OrderChannel channel;
  final String? orderId;
  final String? address;

  String keyFor(CheckoutStage stage) => '$key:${stage.name}';

  PendingCheckout copyWith({CheckoutStage? stage, String? orderId}) =>
      PendingCheckout(
        branchId: branchId,
        key: key,
        stage: stage ?? this.stage,
        items: items,
        channel: channel,
        orderId: orderId ?? this.orderId,
        address: address,
      );

  static const schemaVersion = 1;

  Map<String, dynamic> toJson() => {
        'version': schemaVersion,
        'branchId': branchId,
        'key': key,
        'stage': stage.name,
        'items': items,
        'channel': channel.wire,
        if (orderId != null) 'orderId': orderId,
        if (address != null) 'address': address,
      };

  static PendingCheckout? fromJson(Map<String, dynamic> json) {
    if ((json['version'] as num?)?.toInt() != schemaVersion) return null;
    final branchId = json['branchId'];
    final key = json['key'];
    if (branchId is! String || key is! String) return null;
    return PendingCheckout(
      branchId: branchId,
      key: key,
      stage: CheckoutStage.values.firstWhere(
        (stage) => stage.name == json['stage'],
        // Resuming too early is safe — every step is idempotent. Resuming too
        // late would skip one that never ran.
        orElse: () => CheckoutStage.creating,
      ),
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false),
      channel: OrderChannel.values.firstWhere(
        (channel) => channel.wire == json['channel'],
        orElse: () => OrderChannel.takeaway,
      ),
      orderId: json['orderId'] as String?,
      address: json['address'] as String?,
    );
  }
}

enum CheckoutPhase { idle, placing, placed, failed }

@immutable
class CheckoutState {
  const CheckoutState({
    this.phase = CheckoutPhase.idle,
    this.stage,
    this.error,
    this.orderId,
    this.addressAccepted = true,
    this.pending,
  });

  final CheckoutPhase phase;
  final CheckoutStage? stage;
  final ApiException? error;

  /// Set once the order exists, whatever happened afterwards.
  final String? orderId;

  /// False when the address could not be attached to the order.
  final bool addressAccepted;

  final PendingCheckout? pending;

  bool get isPlacing => phase == CheckoutPhase.placing;

  /// The restaurant may already have an order for this customer even though the
  /// flow did not finish. Saying "nothing was ordered" would be a guess.
  bool get orderExists => orderId != null || pending?.orderId != null;
}

/// Places the order: create, add the items, tell the restaurant.
class CheckoutController extends Notifier<CheckoutState> {
  @override
  CheckoutState build() {
    final pending = _read();
    if (pending == null) return const CheckoutState();
    return CheckoutState(
      phase: CheckoutPhase.failed,
      stage: pending.stage,
      pending: pending,
      orderId: pending.orderId,
    );
  }

  static const _prefix = 'checkout:';

  String get _branchId => ref.read(sessionProvider).branchId ?? '';
  String get _storageKey => '$_prefix$_branchId';

  PendingCheckout? _read() {
    final raw = ref.read(sharedPreferencesProvider).getString(_storageKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      return json is Map<String, dynamic> ? PendingCheckout.fromJson(json) : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> _save(PendingCheckout pending) => ref
      .read(sharedPreferencesProvider)
      .setString(_storageKey, jsonEncode(pending.toJson()));

  Future<void> _forget() =>
      ref.read(sharedPreferencesProvider).remove(_storageKey);

  /// Send the basket to the restaurant, or finish an attempt that was cut off.
  Future<void> place({
    required Cart cart,
    required OrderChannel channel,
    String? address,
  }) async {
    if (state.isPlacing) return;

    var pending = state.pending ??
        _read() ??
        PendingCheckout(
          branchId: _branchId,
          key: _newKey(),
          stage: CheckoutStage.creating,
          items: cart.lines.map((l) => l.toApiJson()).toList(growable: false),
          channel: channel,
          address: address,
        );

    if (pending.items.isEmpty) {
      state = const CheckoutState();
      return;
    }

    await _save(pending);
    state = state.copyWith(
      phase: CheckoutPhase.placing,
      stage: pending.stage,
      pending: pending,
      clearError: true,
    );

    final repository = ref.read(customerOrderRepositoryProvider);
    var addressAccepted = state.addressAccepted;

    try {
      if (pending.stage == CheckoutStage.creating) {
        final created = await repository.create(
          channel: pending.channel,
          address: pending.address,
          idempotencyKey: pending.keyFor(CheckoutStage.creating),
        );
        addressAccepted = created.addressAccepted;
        pending = pending.copyWith(
          orderId: created.order.id,
          stage: CheckoutStage.addingItems,
        );
        await _save(pending);
        state = state.copyWith(
          orderId: created.order.id,
          addressAccepted: addressAccepted,
          stage: CheckoutStage.addingItems,
          pending: pending,
        );
      }

      final orderId = pending.orderId!;

      if (pending.stage == CheckoutStage.addingItems) {
        state = state.copyWith(stage: CheckoutStage.addingItems);
        await repository.addItems(
          orderId: orderId,
          items: pending.items,
          idempotencyKey: pending.keyFor(CheckoutStage.addingItems),
        );
        pending = pending.copyWith(stage: CheckoutStage.placing);
        await _save(pending);
      }

      state = state.copyWith(stage: CheckoutStage.placing);
      await repository.place(
        orderId: orderId,
        idempotencyKey: pending.keyFor(CheckoutStage.placing),
      );

      await _forget();
      // The basket is the restaurant's order now; keeping it would offer to
      // order the same dinner again.
      ref.read(cartControllerProvider.notifier).clear();
      state = CheckoutState(
        phase: CheckoutPhase.placed,
        orderId: orderId,
        addressAccepted: addressAccepted,
      );
    } on ApiException catch (error) {
      state = state.copyWith(
        phase: CheckoutPhase.failed,
        pending: pending,
        error: error,
        addressAccepted: addressAccepted,
      );
    }
  }

  /// Give up on an unfinished attempt. The basket stays, so the customer can
  /// try again — but any order already created is the restaurant's to cancel,
  /// and the screen says so rather than pretending it is gone.
  Future<void> discard() async {
    await _forget();
    state = const CheckoutState();
  }

  static String _newKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}

extension on CheckoutState {
  CheckoutState copyWith({
    CheckoutPhase? phase,
    CheckoutStage? stage,
    ApiException? error,
    String? orderId,
    bool? addressAccepted,
    PendingCheckout? pending,
    bool clearError = false,
  }) =>
      CheckoutState(
        phase: phase ?? this.phase,
        stage: stage ?? this.stage,
        error: clearError ? null : (error ?? this.error),
        orderId: orderId ?? this.orderId,
        addressAccepted: addressAccepted ?? this.addressAccepted,
        pending: pending ?? this.pending,
      );
}

final checkoutControllerProvider =
    NotifierProvider<CheckoutController, CheckoutState>(
  CheckoutController.new,
);
