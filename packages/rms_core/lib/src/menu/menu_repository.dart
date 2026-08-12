import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../domain/menu.dart';
import '../domain/restaurant_config.dart';
import '../net/api_client.dart';
import '../providers.dart';

/// Everything the item picker needs for one outlet.
@immutable
class MenuCatalogue {
  const MenuCatalogue({
    required this.categories,
    required this.items,
    required this.config,
  });

  final List<MenuCategory> categories;
  final List<MenuItem> items;

  /// The branch's tax, service charge and rounding rules — without these a
  /// draft cannot be priced the way the server will price it.
  final RestaurantConfig config;

  /// Items a waiter may actually order, in menu order.
  List<MenuItem> get orderable =>
      items.where((i) => i.isOrderable).toList(growable: false);

  /// Categories that actually have something orderable behind them, so the
  /// picker never offers a chip that leads to an empty grid.
  List<MenuCategory> get populatedCategories {
    final present = orderable.map((i) => i.categoryId).toSet();
    return categories
        .where((c) => present.contains(c.id))
        .toList(growable: false);
  }

  /// True when some orderable item belongs to no category. The seed has one
  /// ("Biryani"), and silently hiding a dish a waiter can see on the paper menu
  /// would be the worst possible failure of a menu screen.
  bool get hasUncategorised => orderable.any((i) => i.categoryId == null);

  List<MenuItem> inCategory(String? categoryId) => orderable
      .where((i) => i.categoryId == categoryId)
      .toList(growable: false);

  /// Local, case-insensitive search over name, SKU and barcode.
  ///
  /// The API supports `?q=`, but a waiter types mid-service with a guest
  /// waiting: filtering the already-loaded catalogue answers each keystroke
  /// instantly and keeps working when the wifi does not. A restaurant menu is
  /// hundreds of rows, not millions — the round trip buys nothing.
  List<MenuItem> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return orderable;
    return orderable.where((i) {
      return i.name.toLowerCase().contains(q) ||
          (i.sku?.toLowerCase().contains(q) ?? false) ||
          (i.barcode?.toLowerCase().contains(q) ?? false);
    }).toList(growable: false);
  }
}

/// Reads the menu for the active outlet, and caches it.
///
/// The catalogue barely changes during a service, so it is fetched once and
/// reused across every table a waiter opens. The cache is keyed on the branch
/// the session was pointing at when it was filled: switching outlets must not
/// leave a waiter ordering from the other branch's prices, and relying on a
/// caller to remember to invalidate is how that bug happens.
class MenuRepository {
  MenuRepository(this._client, this._session);

  final ApiClient _client;
  final Session _session;

  String? _cachedBranchId;
  MenuCatalogue? _catalogue;
  final Map<String, MenuItemDetail> _details = {};
  Future<Map<String, ModifierGroup>>? _modifierGroups;

  Future<MenuCatalogue> catalogue({bool forceRefresh = false}) async {
    _dropCacheIfBranchChanged();
    final cached = _catalogue;
    if (cached != null && !forceRefresh) return cached;

    // Three round trips issued together: sequential calls would make the first
    // item tap of a shift noticeably slow on restaurant wifi.
    final results = await Future.wait([
      _client.get('/restaurant/categories'),
      _client.get(_client.branchScoped('/restaurant/items')),
      _client.get(_client.branchScoped('/restaurant/config')),
    ]);

    final categories = _list(results[0])
        .map(MenuCategory.fromJson)
        .where((c) => c.active)
        .toList(growable: false)
      ..sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        return order != 0 ? order : a.name.compareTo(b.name);
      });

    final items =
        _list(results[1]).map(MenuItem.fromJson).toList(growable: false);

    final config = results[2] is Map<String, dynamic>
        ? RestaurantConfig.fromJson(results[2] as Map<String, dynamic>)
        : RestaurantConfig.fallback;

    final catalogue =
        MenuCatalogue(categories: categories, items: items, config: config);
    _catalogue = catalogue;
    return catalogue;
  }

  /// The detail of one item — the ONLY endpoint that says whether an item has
  /// modifier groups, since `GET /restaurant/items` omits them entirely.
  ///
  /// Cached per item, so the second Chicken Tikka of the night opens instantly.
  Future<MenuItemDetail> detail(String itemId) async {
    _dropCacheIfBranchChanged();
    final cached = _details[itemId];
    if (cached != null) return cached;

    final json =
        await _client.get(_client.branchScoped('/restaurant/items/$itemId'));
    final detail = MenuItemDetail.fromJson(json as Map<String, dynamic>);
    _details[itemId] = detail;
    return detail;
  }

  /// Every modifier group with its choices, keyed by id.
  ///
  /// The list endpoint returns only a count of choices, so the full catalogue
  /// costs one request per group. Groups are tenant-wide and few, so they are
  /// fetched once for the session rather than per item — and a tenant with no
  /// modifier groups at all (like the demo) pays exactly one request.
  Future<Map<String, ModifierGroup>> modifierGroups() {
    _dropCacheIfBranchChanged();
    return _modifierGroups ??= _loadModifierGroups();
  }

  Future<Map<String, ModifierGroup>> _loadModifierGroups() async {
    try {
      final summaries = _list(await _client.get('/restaurant/modifier-groups'));
      if (summaries.isEmpty) return const {};

      final ids = summaries
          .map((json) => json['id'])
          .whereType<String>()
          .toList(growable: false);
      final groups = await Future.wait(
        ids.map((id) => _client.get('/restaurant/modifier-groups/$id')),
      );

      return {
        for (final json in groups.whereType<Map<String, dynamic>>())
          json['id'] as String: ModifierGroup.fromJson(json),
      };
    } catch (_) {
      // A failed fetch must not be remembered as "this tenant has no options",
      // or every item for the rest of the shift would be added unconfigured.
      _modifierGroups = null;
      rethrow;
    }
  }

  void _dropCacheIfBranchChanged() {
    final branchId = _session.branchId;
    if (branchId == _cachedBranchId) return;
    _cachedBranchId = branchId;
    _catalogue = null;
    _details.clear();
    _modifierGroups = null;
  }

  static List<Map<String, dynamic>> _list(dynamic data) {
    if (data is List) return data.whereType<Map<String, dynamic>>().toList();
    if (data is Map<String, dynamic> && data['items'] is List) {
      return (data['items'] as List).whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }
}

final menuRepositoryProvider = Provider<MenuRepository>(
  (ref) => MenuRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionProvider),
  ),
);

/// The menu for the active outlet. Deliberately not `autoDispose`: it outlives
/// the picker sheet so opening the menu at the next table is instant.
final menuCatalogueProvider = FutureProvider<MenuCatalogue>(
  (ref) => ref.watch(menuRepositoryProvider).catalogue(),
);

/// Whether this tenant defines any modifier groups at all.
///
/// When it defines none — as the demo tenant does — no item can require
/// configuring, so the picker adds on a single tap instead of making the waiter
/// confirm a sheet with nothing in it. Costs exactly one request per session.
final tenantHasModifiersProvider = FutureProvider<bool>((ref) async {
  final groups = await ref.watch(menuRepositoryProvider).modifierGroups();
  return groups.isNotEmpty;
});

/// An item's modifier groups, resolved against the tenant-wide catalogue.
///
/// Empty means "this item takes no options" — which is only known after the
/// detail call, never from the list.
final itemModifierGroupsProvider =
    FutureProvider.autoDispose.family<List<ModifierGroup>, String>(
  (ref, itemId) async {
    final repository = ref.watch(menuRepositoryProvider);
    final detail = await repository.detail(itemId);
    if (detail.modifierGroups.isEmpty) return const [];

    final catalogue = await repository.modifierGroups();
    // Attachment order is the menu designer's; a group missing from the
    // catalogue (deleted mid-service) is dropped rather than rendered empty.
    return detail.modifierGroups
        .map((ref) => catalogue[ref.id])
        .whereType<ModifierGroup>()
        .toList(growable: false);
  },
);
