import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rms_core/rms_core.dart';
import '../../../app/router/app_router.dart';
import '../../../l10n/app_text.dart';
import '../../cart/application/cart_controller.dart';

/// The menu a guest orders from.
///
/// Unlike the waiter's picker this one sells: photographs, generous tiles, and
/// prices shown the way they will be charged. A waiter is scanning for a dish
/// they already know the name of; a customer is deciding.
class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  String _query = '';
  String? _categoryId;

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(menuCatalogueProvider);
    final cart = ref.watch(cartControllerProvider);
    final text = appText(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(text.menu),
        actions: [
          IconButton(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).clearBranch(),
            icon: const Icon(Icons.storefront_outlined),
            tooltip: text.changeRestaurant,
          ),
          IconButton(
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout_rounded),
            tooltip: text.signOut,
          ),
        ],
      ),
      body: catalogue.when(
        loading: () => LoadingView(message: text.menuLoading),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(menuCatalogueProvider),
        ),
        data: (catalogue) => _MenuBody(
          catalogue: catalogue,
          query: _query,
          categoryId: _categoryId,
          onQuery: (value) => setState(() => _query = value),
          onCategory: (value) => setState(() => _categoryId = value),
        ),
      ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: SizedBox(
                  height: AppSizes.primaryActionHeight,
                  child: FilledButton.icon(
                    onPressed: () => context.push(Routes.cart),
                    icon: const Icon(Icons.shopping_bag_rounded),
                    label: Text(text.basketWithCount(cart.itemCount)),
                  ),
                ),
              ),
            ),
    );
  }
}

class _MenuBody extends ConsumerWidget {
  const _MenuBody({
    required this.catalogue,
    required this.query,
    required this.categoryId,
    required this.onQuery,
    required this.onCategory,
  });

  final MenuCatalogue catalogue;
  final String query;
  final String? categoryId;
  final ValueChanged<String> onQuery;
  final ValueChanged<String?> onCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = appText(context);
    final searching = query.trim().isNotEmpty;
    final items = searching
        ? catalogue.search(query)
        : categoryId == null
            ? catalogue.orderable
            : catalogue.inCategory(categoryId);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: TextField(
            onChanged: onQuery,
            decoration: InputDecoration(
              hintText: text.searchTheMenu,
              prefixIcon: const Icon(Icons.search_rounded),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        if (!searching && catalogue.populatedCategories.isNotEmpty)
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    selected: categoryId == null,
                    onSelected: (_) => onCategory(null),
                    label: Text(text.everything),
                  ),
                ),
                for (final category in catalogue.populatedCategories)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      selected: categoryId == category.id,
                      onSelected: (_) => onCategory(category.id),
                      label: Text(category.name),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: items.isEmpty
              ? EmptyView(
                  icon: Icons.search_off_rounded,
                  title: searching
                      ? text.nothingMatchesTitle
                      : text.nothingOnMenuTitle,
                  message: searching
                      ? text.tryAnotherWord
                      : text.noMenuPublished,
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) => _DishTile(
                    item: items[index],
                    config: catalogue.config,
                  ),
                ),
        ),
      ],
    );
  }
}

class _DishTile extends ConsumerWidget {
  const _DishTile({required this.item, required this.config});

  final MenuItem item;
  final RestaurantConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final text = appText(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          ref.read(cartControllerProvider.notifier).add(item, config);
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(text.addedNamed(item.name)),
                duration: const Duration(milliseconds: 900),
              ),
            );
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              if (item.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Image.network(
                    item.imageUrl!,
                    width: 84,
                    height: 84,
                    fit: BoxFit.cover,
                    // A dish with a broken photo is still a dish somebody wants
                    // to order; it must not take the tile down with it.
                    errorBuilder: (_, __, ___) => const _NoPhoto(),
                    loadingBuilder: (context, child, progress) =>
                        progress == null ? child : const _NoPhoto(),
                  ),
                )
              else
                const _NoPhoto(),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (item.prepMinutes > 0) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        text.prepMinutes(item.prepMinutes),
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      item.price.display,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              IconButton.filled(
                onPressed: () =>
                    ref.read(cartControllerProvider.notifier).add(item, config),
                icon: const Icon(Icons.add_rounded),
                tooltip: text.addNamed(item.name),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoPhoto extends StatelessWidget {
  const _NoPhoto();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(
        Icons.restaurant_rounded,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }
}
