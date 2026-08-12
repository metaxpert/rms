import 'package:flutter/foundation.dart';

import 'table_status.dart';

/// Where a table sits on the floor designer's canvas, in its own arbitrary
/// units. The app scales these to the device rather than assuming pixels.
@immutable
class TablePosition {
  const TablePosition({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.rotation,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;

  static TablePosition? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final x = _num(json['x']);
    final y = _num(json['y']);
    if (x == null || y == null) return null;
    return TablePosition(
      x: x,
      y: y,
      width: _num(json['width']) ?? 88,
      height: _num(json['height']) ?? 64,
      rotation: _num(json['rotation']) ?? 0,
    );
  }

  /// The API may send ints or doubles depending on how a table was created
  /// (designer drag vs. seeded fixture).
  static double? _num(Object? value) => switch (value) {
        final num n => n.toDouble(),
        final String s => double.tryParse(s),
        _ => null,
      };
}

/// A table. Verified shape from `GET /restaurant/tables`.
@immutable
class RestaurantTable {
  const RestaurantTable({
    required this.id,
    required this.areaId,
    required this.areaName,
    required this.branchId,
    required this.code,
    required this.capacity,
    required this.shape,
    required this.status,
    required this.active,
    this.position,
    this.mergedIntoId,
  });

  final String id;
  final String areaId;
  final String areaName;
  final String branchId;

  /// What staff call it — "D1", "T12". Never show the UUID.
  final String code;
  final int capacity;

  /// `RECT`, `ROUND`, … Rendered as a hint; an unknown shape falls back to a
  /// rectangle rather than failing to draw the table at all.
  final String shape;
  final TableStatus status;
  final bool active;
  final TablePosition? position;

  /// Set when this table has been merged into another; the merged-away table
  /// must not be independently seated.
  final String? mergedIntoId;

  bool get isMerged => mergedIntoId != null;

  /// Whether tapping should open/continue an order.
  bool get isOperable => active && !isMerged;

  factory RestaurantTable.fromJson(Map<String, dynamic> json) =>
      RestaurantTable(
        id: json['id'] as String,
        areaId: (json['areaId'] as String?) ?? '',
        areaName: (json['area'] as String?) ?? '',
        branchId: (json['branchId'] as String?) ?? '',
        code: (json['code'] as String?) ?? '?',
        capacity: (json['capacity'] as num?)?.toInt() ?? 0,
        shape: (json['shape'] as String?) ?? 'RECT',
        status: TableStatus.fromWire(json['status'] as String?),
        active: json['active'] as bool? ?? true,
        position:
            TablePosition.fromJson(json['position'] as Map<String, dynamic>?),
        mergedIntoId: json['mergedIntoId'] as String?,
      );

  @override
  bool operator ==(Object other) => other is RestaurantTable && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A dining area. Verified shape from `GET /restaurant/areas`.
@immutable
class FloorArea {
  const FloorArea({
    required this.id,
    required this.branchId,
    required this.name,
    required this.kind,
    required this.sortOrder,
    required this.tableCount,
  });

  final String id;
  final String branchId;
  final String name;

  /// `INDOOR`, `OUTDOOR`, `TERRACE`, `GARDEN`.
  final String kind;
  final int sortOrder;
  final int tableCount;

  factory FloorArea.fromJson(Map<String, dynamic> json) => FloorArea(
        id: json['id'] as String,
        branchId: (json['branchId'] as String?) ?? '',
        name: (json['name'] as String?) ?? 'Area',
        kind: (json['kind'] as String?) ?? 'INDOOR',
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        tableCount: (json['tableCount'] as num?)?.toInt() ?? 0,
      );

  @override
  bool operator ==(Object other) => other is FloorArea && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
