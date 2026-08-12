import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rms_core/rms_core.dart';
import '../data/menu_repository.dart';
import 'item_options_sheet.dart';

/// The menu, as a full-height sheet over the ticket.
///
/// It stays open while dishes are added: a table orders five things at once, and
/// closing the menu after each one would cost four extra taps and lose the
/// waiter's place in the list.
Future<void> showMenuPickerSheet(
  BuildContext context, {
  required String tableCode,
  required ValueChanged<DraftLine> onAdd,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _MenuPickerSheet(tableCode: tableCode, onAdd: onAdd),
  );
}

class _MenuPickerSheet extends ConsumerStatefulWidget {
  const _MenuPickerSheet({required this.tableCode, required this.onAdd});

  final String tableCode;
  final ValueChanged<DraftLine> onAdd;

  @override
  ConsumerState<_MenuPickerSheet> createState() => _MenuPickerSheetState();
}

/// Sentinel for the "not in any category" chip — the seed has such an item, and
/// a dish a waiter can see on the paper menu must be reachable here.
const _uncategorised = '__uncategorised__';

class _MenuPickerSheetState extends ConsumerState<_MenuPickerSheet> {
  final _search = TextEditingController();
  String? _categoryId;
  int _added = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pick(MenuItem item, RestaurantConfig config) async {
    // Whether an item takes options is only knowable from its detail call, so
    // when the tenant has no modifier groups at all the tap adds immediately —
    // the common case, and the difference between one tap and three.
    final hasModifiers =
        ref.read(tenantHasModifiersProvider).valueOrNull ?? true;

    if (!hasModifiers) {
      _add(DraftLine.fromMenuItem(item, config: config));
      return;
    }

    final line = await showItemOptionsSheet(
      context,
      item: item,
      config: config,
    );
    if (line != null) _add(line);
  }

  void _add(DraftLine line) {
    widget.onAdd(line);
    setState(() => _added += line.qty);

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('${line.qty} × ${line.name}'),
          duration: const Duration(milliseconds: 900),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catalogue = ref.watch(menuCatalogueProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Add to ${widget.tableCode}',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(_added == 0 ? 'Close' : 'Done · $_added'),
                ),
              ],
            ),
          ),
          Expanded(
            child: catalogue.when(
              loading: () => const LoadingView(message: 'Loading the menu…'),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(menuCatalogueProvider),
              ),
              data: (catalogue) => _Browser(
                catalogue: catalogue,
                scrollController: scrollController,
                search: _search,
                categoryId: _categoryId,
                onSearchChanged: (_) => setState(() {}),
                onCategoryChanged: (id) => setState(() => _categoryId = id),
                onPick: (item) => _pick(item, catalogue.config),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Browser extends StatelessWidget {
  const _Browser({
    required this.catalogue,
    required this.scrollController,
    required this.search,
    required this.categoryId,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onPick,
  });

  final MenuCatalogue catalogue;
  final ScrollController scrollController;
  final TextEditingController search;
  final String? categoryId;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<MenuItem> onPick;

  @override
  Widget build(BuildContext context) {
    final query = search.text.trim();
    // Searching looks across the whole menu: a waiter typing "naan" wants the
    // naan, not to be told there is none in the category they last tapped.
    final items = query.isNotEmpty
        ? catalogue.search(query)
        : categoryId == null
            ? catalogue.orderable
            : catalogue.inCategory(
                categoryId == _uncategorised ? null : categoryId);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: TextField(
            controller: search,
            onChanged: onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search dishes',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        search.clear();
                        onSearchChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Clear',
                    ),
            ),
          ),
        ),
        if (query.isEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _Categories(
            catalogue: catalogue,
            selectedId: categoryId,
            onSelected: onCategoryChanged,
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: items.isEmpty
              ? EmptyView(
                  icon: Icons.search_off_rounded,
                  title: query.isEmpty ? 'Nothing here' : 'No match for "$query"',
                  message: query.isEmpty
                      ? 'Every dish in this section is off the menu right now.'
                      : 'Sold-out dishes are not listed.',
                )
              : GridView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: AppSizes.menuItemMin,
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    childAspectRatio: 1.25,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) => _ItemTile(
                    item: items[index],
                    onTap: () => onPick(items[index]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _Categories extends StatelessWidget {
  const _Categories({
    required this.catalogue,
    required this.selectedId,
    required this.onSelected,
  });

  final MenuCatalogue catalogue;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final categories = catalogue.populatedCategories;

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          ChoiceChip(
            selected: selectedId == null,
            onSelected: (_) => onSelected(null),
            label: const Text('All'),
          ),
          for (final category in categories) ...[
            const SizedBox(width: AppSpacing.sm),
            ChoiceChip(
              selected: selectedId == category.id,
              onSelected: (_) => onSelected(category.id),
              label: Text(category.name),
            ),
          ],
          if (catalogue.hasUncategorised) ...[
            const SizedBox(width: AppSpacing.sm),
            ChoiceChip(
              selected: selectedId == _uncategorised,
              onSelected: (_) => onSelected(_uncategorised),
              label: const Text('Other'),
            ),
          ],
        ],
      ),
    );
  }
}

/// A dish tile: name and price, no photograph.
///
/// The customer app sells with pictures; a waiter already knows the menu and is
/// scanning for a name. Loading a photo per tile would slow the grid on the
/// same restaurant wifi the order has to travel over.
class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.onTap});

  final MenuItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: theme.textTheme.titleSmall,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                item.price.display,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
              if (item.isCombo)
                Text(
                  'Combo',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
