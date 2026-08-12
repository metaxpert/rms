import 'package:flutter/foundation.dart';

/// Per-branch restaurant configuration, from `GET /restaurant/config?branchId=`.
///
/// Only the fields the apps actually price or behave off are modelled. The
/// endpoint returns considerably more (warehouse, receipt header/footer, fiscal
/// tax number); those belong to the web console's settings screen, and copying
/// them here would imply the app honours settings it ignores.
@immutable
class RestaurantConfig {
  const RestaurantConfig({
    required this.currency,
    required this.defaultTaxBp,
    required this.serviceChargeBp,
    required this.roundingEnabled,
    required this.tipEnabled,
    required this.autoFireKitchen,
  });

  final String currency;

  /// Tax in basis points for items that do not override it (1600 = 16%).
  final int defaultTaxBp;

  /// Service charge on the taxable amount, applied to the order as a whole.
  final int serviceChargeBp;

  /// Whether the bill is rounded to the nearest rupee. Pakistani restaurants
  /// generally do — the 1- and 2-rupee coins have effectively left circulation.
  final bool roundingEnabled;
  final bool tipEnabled;

  /// When true, placing an order confirms it and fires the kitchen in the same
  /// call, so a waiter never has to "confirm" separately.
  final bool autoFireKitchen;

  /// A safe default for a backend that has no config row for the branch: the
  /// server itself falls back to 0 tax, so charging tax the server will not
  /// charge would put the till out against the bill.
  static const fallback = RestaurantConfig(
    currency: 'PKR',
    defaultTaxBp: 0,
    serviceChargeBp: 0,
    roundingEnabled: true,
    tipEnabled: true,
    autoFireKitchen: true,
  );

  factory RestaurantConfig.fromJson(Map<String, dynamic> json) =>
      RestaurantConfig(
        currency: (json['currency'] as String?) ?? 'PKR',
        defaultTaxBp: (json['defaultTaxBp'] as num?)?.toInt() ?? 0,
        serviceChargeBp: (json['serviceChargeBp'] as num?)?.toInt() ?? 0,
        roundingEnabled: json['roundingEnabled'] as bool? ?? true,
        tipEnabled: json['tipEnabled'] as bool? ?? true,
        autoFireKitchen: json['autoFireKitchen'] as bool? ?? true,
      );
}
