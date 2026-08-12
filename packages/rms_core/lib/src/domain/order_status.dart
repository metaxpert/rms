import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Order lifecycle, mirroring the backend exactly (brief §13 — map the real
/// statuses, do not invent names).
///
/// `DRAFT → PLACED → CONFIRMED → PREPARING → READY → SERVED → SETTLED`, with
/// `CANCELLED` / `VOID` as terminal exits.
enum OrderStatus {
  draft('DRAFT'),
  placed('PLACED'),
  confirmed('CONFIRMED'),
  preparing('PREPARING'),
  ready('READY'),
  served('SERVED'),
  settled('SETTLED'),
  cancelled('CANCELLED'),
  voided('VOID'),
  unknown('UNKNOWN');

  const OrderStatus(this.wire);

  final String wire;

  static OrderStatus fromWire(String? value) {
    for (final status in values) {
      if (status.wire == value) return status;
    }
    return OrderStatus.unknown;
  }

  /// Still occupying a table and owing money.
  bool get isOpen => switch (this) {
        OrderStatus.settled ||
        OrderStatus.cancelled ||
        OrderStatus.voided ||
        // An unrecognised status is NOT assumed open: showing a phantom bill on
        // a free table is worse than missing a badge, and the table's own
        // status still drives the colour.
        OrderStatus.unknown =>
          false,
        _ => true,
      };

  /// Food is up and waiting to be run to the table — the one status a waiter
  /// must notice immediately.
  bool get needsAttention => this == OrderStatus.ready;

  String get label => switch (this) {
        OrderStatus.draft => 'Draft',
        OrderStatus.placed => 'Placed',
        OrderStatus.confirmed => 'Confirmed',
        OrderStatus.preparing => 'Cooking',
        OrderStatus.ready => 'Ready',
        OrderStatus.served => 'Served',
        OrderStatus.settled => 'Settled',
        OrderStatus.cancelled => 'Cancelled',
        OrderStatus.voided => 'Voided',
        OrderStatus.unknown => 'Unknown',
      };

  Color get color => switch (this) {
        OrderStatus.draft => AppStatusColors.settled,
        OrderStatus.placed => AppStatusColors.ordering,
        OrderStatus.confirmed => AppStatusColors.ordering,
        OrderStatus.preparing => AppStatusColors.preparing,
        OrderStatus.ready => AppStatusColors.ready,
        OrderStatus.served => AppStatusColors.served,
        OrderStatus.settled => AppStatusColors.settled,
        OrderStatus.cancelled ||
        OrderStatus.voided =>
          AppStatusColors.cancelled,
        OrderStatus.unknown => AppStatusColors.settled,
      };

  IconData get icon => switch (this) {
        OrderStatus.draft => Icons.edit_note_outlined,
        OrderStatus.placed => Icons.receipt_long_outlined,
        OrderStatus.confirmed => Icons.check_outlined,
        OrderStatus.preparing => Icons.local_fire_department_outlined,
        OrderStatus.ready => Icons.room_service_outlined,
        OrderStatus.served => Icons.done_all_outlined,
        OrderStatus.settled => Icons.payments_outlined,
        OrderStatus.cancelled || OrderStatus.voided => Icons.cancel_outlined,
        OrderStatus.unknown => Icons.help_outline,
      };
}
