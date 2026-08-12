import 'package:flutter/foundation.dart';

import '../money.dart';

/// The menu catalogue, mirroring the backend's shapes exactly.
///
/// Read from `menu.service.ts` and verified against the live Karahi Point seed.
/// The catalogue is tenant-wide; a *branch* only overrides an item's price and
/// availability (`restaurant_menu_item_branch`), which the API has already
/// resolved into `effectivePrice` / `available` by the time the app sees it —
/// so every read here must be branch-scoped or the waiter is shown another
/// outlet's prices.

/// A row from `GET /restaurant/categories`.
@immutable
class MenuCategory {
  const MenuCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.active,
    required this.itemCount,
    this.parentId,
  });

  final String id;
  final String name;
  final int sortOrder;
  final bool active;

  /// Counts every item in the category, including inactive ones — so it may
  /// exceed what the waiter can actually see and is not used as a badge.
  final int itemCount;

  /// Categories nest server-side. The waiter's menu flattens them: a waiter
  /// hunting for "Garlic Naan" mid-service should not have to know it lives
  /// under Breads → Tandoor.
  final String? parentId;

  factory MenuCategory.fromJson(Map<String, dynamic> json) => MenuCategory(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? 'Category',
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        active: json['active'] as bool? ?? true,
        itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
        parentId: json['parentId'] as String?,
      );

  @override
  bool operator ==(Object other) => other is MenuCategory && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A row from `GET /restaurant/items?branchId=…`.
///
/// This shape is what the menu grid renders. It deliberately does NOT carry
/// modifier groups: the list endpoint omits them entirely, and only
/// `GET /restaurant/items/:id` knows which groups an item has. See
/// [MenuItemDetail].
@immutable
class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.available,
    required this.status,
    required this.isCombo,
    required this.prepMinutes,
    this.categoryId,
    this.categoryName,
    this.sku,
    this.barcode,
    this.taxBp,
    this.stationKey,
    this.imageUrl,
  });

  final String id;
  final String name;

  /// The branch-effective price — the per-branch override when one exists,
  /// otherwise the base price. The base price is not modelled because showing
  /// it would only invite charging it.
  final Money price;

  /// Already the AND of item- and branch-level availability, server-side.
  final bool available;

  /// `ACTIVE`, `SOLD_OUT`, … Availability and status are separate flags on the
  /// backend and an item is orderable only when `ACTIVE` *and* available, which
  /// is what [isOrderable] encodes.
  final String status;
  final bool isCombo;
  final int prepMinutes;

  final String? categoryId;
  final String? categoryName;
  final String? sku;
  final String? barcode;

  /// Per-item tax override in basis points. **Null means "use the branch's
  /// default"** — it is not zero-rated. Resolving that fallback wrongly would
  /// under-charge tax on every line of that item.
  final int? taxBp;

  /// Which kitchen station cooks it. Carried so a line can be shown against its
  /// station later; the server does the actual KDS routing.
  final String? stationKey;

  /// `imageKey` is a full URL in the seed and may be a storage key elsewhere,
  /// so it is only used when it parses as an http(s) URL.
  final String? imageUrl;

  bool get isOrderable => available && status == 'ACTIVE';

  /// Tax rate for this item at a branch whose default is [defaultTaxBp].
  int resolvedTaxBp(int defaultTaxBp) => taxBp ?? defaultTaxBp;

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    final price = json['effectivePrice'] ?? json['basePrice'];
    final currency = (json['currency'] as String?) ?? 'PKR';
    return MenuItem(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Item',
      price: price is Map<String, dynamic>
          ? Money(
              (price['amountMinor'] as num?)?.toInt() ?? 0,
              (price['currency'] as String?) ?? currency,
            )
          : Money(0, currency),
      available: json['available'] as bool? ?? true,
      status: (json['status'] as String?) ?? 'ACTIVE',
      isCombo: json['isCombo'] as bool? ?? false,
      prepMinutes: (json['prepMinutes'] as num?)?.toInt() ?? 0,
      categoryId: json['categoryId'] as String?,
      categoryName: json['category'] as String?,
      sku: json['sku'] as String?,
      barcode: json['barcode'] as String?,
      taxBp: (json['taxBp'] as num?)?.toInt(),
      stationKey: json['stationKey'] as String?,
      imageUrl: _httpUrl(json['imageKey']),
    );
  }

  static String? _httpUrl(Object? value) {
    if (value is! String || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    return (uri != null && (uri.scheme == 'http' || uri.scheme == 'https'))
        ? value
        : null;
  }

  @override
  bool operator ==(Object other) => other is MenuItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The extra fields `GET /restaurant/items/:id` adds, chiefly which modifier
/// groups apply.
///
/// Fetching this is the only way to learn whether an item needs configuring:
/// the list endpoint does not say. Kept as a separate type rather than nullable
/// fields on [MenuItem] so "not loaded yet" cannot be confused with "has none".
@immutable
class MenuItemDetail {
  const MenuItemDetail({
    required this.id,
    required this.modifierGroups,
    required this.allergens,
    required this.tags,
    this.description,
    this.calories,
  });

  final String id;

  /// Attachments, in the order the menu designer set. These carry the group's
  /// rules but NOT its choices — the choices come from
  /// `GET /restaurant/modifier-groups/:id` ([ModifierGroup]).
  final List<ModifierGroupRef> modifierGroups;
  final List<String> allergens;
  final List<String> tags;
  final String? description;
  final int? calories;

  bool get needsConfiguration => modifierGroups.isNotEmpty;

  factory MenuItemDetail.fromJson(Map<String, dynamic> json) => MenuItemDetail(
        id: json['id'] as String,
        modifierGroups: ((json['modifierGroups'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ModifierGroupRef.fromJson)
            .toList(growable: false)
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
        allergens: _strings(json['allergens']),
        tags: _strings(json['tags']),
        description: json['description'] as String?,
        calories: (json['calories'] as num?)?.toInt(),
      );

  static List<String> _strings(Object? value) => value is List
      ? value.whereType<String>().toList(growable: false)
      : const [];
}

/// A modifier group as attached to an item: the selection rules, without the
/// choices.
@immutable
class ModifierGroupRef {
  const ModifierGroupRef({
    required this.id,
    required this.name,
    required this.minSelect,
    required this.required,
    required this.sortOrder,
    this.maxSelect,
  });

  final String id;
  final String name;
  final int minSelect;

  /// Null means unlimited.
  final int? maxSelect;
  final bool required;
  final int sortOrder;

  factory ModifierGroupRef.fromJson(Map<String, dynamic> json) =>
      ModifierGroupRef(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? 'Options',
        minSelect: (json['minSelect'] as num?)?.toInt() ?? 0,
        maxSelect: (json['maxSelect'] as num?)?.toInt(),
        required: json['required'] as bool? ?? false,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      );

  @override
  bool operator ==(Object other) => other is ModifierGroupRef && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A modifier group WITH its choices, from `GET /restaurant/modifier-groups/:id`.
///
/// The list endpoint (`GET /restaurant/modifier-groups`) returns only a count of
/// choices, so the full catalogue costs one request per group. Groups are
/// tenant-wide and few, so they are fetched once and cached rather than per
/// item.
@immutable
class ModifierGroup {
  const ModifierGroup({
    required this.id,
    required this.name,
    required this.minSelect,
    required this.required,
    required this.sortOrder,
    required this.modifiers,
    this.maxSelect,
  });

  final String id;
  final String name;
  final int minSelect;
  final int? maxSelect;
  final bool required;
  final int sortOrder;
  final List<Modifier> modifiers;

  /// Choices a waiter may actually pick. An unavailable modifier is rejected at
  /// `POST /orders/:id/items` with a 422, so it must not be offered.
  List<Modifier> get selectable =>
      modifiers.where((m) => m.available).toList(growable: false);

  /// How many choices this group demands. `required` and `minSelect` are
  /// independent columns and the seed data may set either, so a required group
  /// with `minSelect: 0` still needs one pick.
  int get effectiveMinSelect =>
      required && minSelect < 1 ? 1 : minSelect;

  factory ModifierGroup.fromJson(Map<String, dynamic> json) => ModifierGroup(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? 'Options',
        minSelect: (json['minSelect'] as num?)?.toInt() ?? 0,
        maxSelect: (json['maxSelect'] as num?)?.toInt(),
        required: json['required'] as bool? ?? false,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        modifiers: ((json['modifiers'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Modifier.fromJson)
            .toList(growable: false),
      );

  @override
  bool operator ==(Object other) => other is ModifierGroup && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// One choice within a group — "Extra spicy", "No onions", "Add cheese".
@immutable
class Modifier {
  const Modifier({
    required this.id,
    required this.name,
    required this.priceDelta,
    required this.available,
    required this.sortOrder,
  });

  final String id;
  final String name;

  /// Per unit of the parent line, and may be zero ("No onions") or negative in
  /// principle.
  final Money priceDelta;
  final bool available;
  final int sortOrder;

  factory Modifier.fromJson(Map<String, dynamic> json) {
    final delta = json['priceDelta'];
    return Modifier(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Option',
      priceDelta: delta is Map<String, dynamic>
          ? Money(
              (delta['amountMinor'] as num?)?.toInt() ?? 0,
              (delta['currency'] as String?) ?? 'PKR',
            )
          : Money.zero,
      available: json['available'] as bool? ?? true,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) => other is Modifier && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
