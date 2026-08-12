import 'package:flutter/foundation.dart';

/// An outlet. Verified shape from `GET /restaurant/branches`:
/// `{ id, name, code, isHeadOffice, active, configured }`.
@immutable
class Branch {
  const Branch({
    required this.id,
    required this.name,
    required this.code,
    required this.isHeadOffice,
    required this.active,
    required this.configured,
  });

  final String id;
  final String name;
  final String code;
  final bool isHeadOffice;
  final bool active;

  /// Whether restaurant config (default warehouse, tax, channels) exists for
  /// this outlet. An unconfigured branch will accept an order and then fail at
  /// settlement, so the picker must not let a waiter choose one.
  final bool configured;

  bool get isSelectable => active && configured;

  /// Tolerant of missing/renamed fields (brief §34): an outlet that loses its
  /// `code` should still render rather than crashing the picker mid-service.
  factory Branch.fromJson(Map<String, dynamic> json) => Branch(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? 'Unnamed outlet',
        code: (json['code'] as String?) ?? '',
        isHeadOffice: json['isHeadOffice'] as bool? ?? false,
        active: json['active'] as bool? ?? true,
        // Absent `configured` is treated as configured: an older backend that
        // does not report the field must not lock every outlet out.
        configured: json['configured'] as bool? ?? true,
      );

  @override
  bool operator ==(Object other) => other is Branch && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
