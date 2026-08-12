import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';

/// Table states, mirroring the backend's `TableStatus` exactly.
///
/// Names are the server's, not invented for the UI (brief §6/§13). `unknown`
/// exists so a status added server-side later renders as an unfamiliar table
/// rather than crashing the floor mid-service (brief §34).
enum TableStatus {
  available('AVAILABLE'),
  reserved('RESERVED'),
  waiting('WAITING'),
  occupied('OCCUPIED'),
  cleaning('CLEANING'),
  unknown('UNKNOWN');

  const TableStatus(this.wire);

  final String wire;

  static TableStatus fromWire(String? value) {
    for (final status in values) {
      if (status.wire == value) return status;
    }
    return TableStatus.unknown;
  }

  String get label => switch (this) {
        TableStatus.available => 'Free',
        TableStatus.reserved => 'Reserved',
        TableStatus.waiting => 'Waiting',
        TableStatus.occupied => 'Seated',
        TableStatus.cleaning => 'Cleaning',
        TableStatus.unknown => 'Unknown',
      };

  /// Paired with [label] and never used alone — roughly 1 in 12 men has a
  /// colour-vision deficiency and restaurant staff are not screened (brief §25).
  Color get color => switch (this) {
        TableStatus.available => AppStatusColors.available,
        TableStatus.reserved => AppStatusColors.reserved,
        TableStatus.waiting => AppStatusColors.ordering,
        TableStatus.occupied => AppStatusColors.seated,
        TableStatus.cleaning => AppStatusColors.served,
        TableStatus.unknown => AppStatusColors.settled,
      };

  IconData get icon => switch (this) {
        TableStatus.available => Icons.check_circle_outline,
        TableStatus.reserved => Icons.event_available_outlined,
        TableStatus.waiting => Icons.hourglass_top_outlined,
        TableStatus.occupied => Icons.people_alt_outlined,
        TableStatus.cleaning => Icons.cleaning_services_outlined,
        TableStatus.unknown => Icons.help_outline,
      };
}

/// Legal transitions, mirroring `TABLE_STATUS_TRANSITIONS` in
/// `restaurant.util.ts`.
///
/// Duplicated deliberately and narrowly: it is used ONLY to grey out actions
/// that would be rejected, so a waiter is not invited to tap something that
/// fails (brief §8). The server re-validates every move and remains the sole
/// authority — this must never be relied on to enforce anything (brief §21).
/// If the two drift, the server wins and the UI simply shows an error.
const Map<TableStatus, List<TableStatus>> kTableTransitions = {
  TableStatus.available: [
    TableStatus.occupied,
    TableStatus.reserved,
    TableStatus.waiting,
    TableStatus.cleaning,
  ],
  TableStatus.reserved: [
    TableStatus.occupied,
    TableStatus.waiting,
    TableStatus.available,
    TableStatus.cleaning,
  ],
  TableStatus.waiting: [
    TableStatus.occupied,
    TableStatus.available,
    TableStatus.cleaning,
  ],
  TableStatus.occupied: [TableStatus.cleaning, TableStatus.available],
  TableStatus.cleaning: [TableStatus.available],
};

bool canTransitionTable(TableStatus from, TableStatus to) {
  if (from == to) return true;
  // An unrecognised source state means our map is out of date; let the server
  // decide rather than blocking a waiter who needs to seat a guest.
  if (from == TableStatus.unknown) return true;
  return kTableTransitions[from]?.contains(to) ?? false;
}
