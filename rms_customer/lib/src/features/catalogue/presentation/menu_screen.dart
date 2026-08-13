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
  final _search = TextEditingController();
  String _query = '';
  String? _categoryId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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
        loading: () => LoadingView(
          message: text.menuLoading,
          skeleton: const _MenuSkeleton(),
        ),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(menuCatalogueProvider),
        ),
        data: (catalogue) => _MenuBody(
          catalogue: catalogue,
          search: _search,
          query: _query,
          categoryId: _categoryId,
          onQuery: (value) => setState(() => _query = value),
          onCategory: (value) => setState(() => _categoryId = value),
        ),
      ),
      // Slides up when the basket stops being empty rather than appearing under
      // the thumb mid-tap — the list resizes either way, and a bar that arrives
      // instantly is a bar somebody presses by accident.
      bottomNavigationBar: AnimatedSize(
        duration: AppMotion.of(context),
        curve: AppMotion.enter,
        alignment: Alignment.topCenter,
        child: cart.isEmpty
            ? const SizedBox(width: double.infinity)
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
      ),
    );
  }
}

/// The menu's shape while it loads: the search box, the category chips, then
/// dish rows with a photo well on the left.
class _MenuSkeleton extends StatelessWidget {
  const _MenuSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonGroup(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const Skeleton(height: 48, radius: AppRadius.md),
          const SizedBox(height: AppSpacing.lg),
          const Row(
            children: [
              Skeleton(width: 96, height: 34, radius: AppRadius.pill),
              SizedBox(width: AppSpacing.sm),
              Skeleton(width: 78, height: 34, radius: AppRadius.pill),
              SizedBox(width: AppSpacing.sm),
              Skeleton(width: 104, height: 34, radius: AppRadius.pill),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < 5; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: Skeleton.box(height: 116),
            ),
        ],
      ),
    );
  }
}

class _MenuBody extends ConsumerWidget {
  const _MenuBody({
    required this.catalogue,
    required this.search,
    required this.query,
    required this.categoryId,
    required this.onQuery,
    required this.onCategory,
  });

  final MenuCatalogue catalogue;
  final TextEditingController search;
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
          // Was a bare TextField overriding the themed decoration with its own
          // border, so the one field a guest actually types in looked unlike
          // every other field in the product.
          child: AppSearchField(
            controller: search,
            hintText: text.searchTheMenu,
            clearTooltip: text.clearSearch,
            onChanged: onQuery,
          ),
        ),
        if (!searching && catalogue.populatedCategories.isNotEmpty)
          SizedBox(
            height: 56,
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
              // A dish tile is a wide row, and on a 1194-pixel tablet an
              // unconstrained one strands the price a hand's width from the
              // dish it belongs to. The fix is to stop the column growing, not
              // to make two of them: a grid row is a fixed height and a dish
              // tile is not, so pinning one to the other clips the price off
              // every tile the moment a guest turns their text size up.
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView.separated(
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

  /// Square, and the same square whether the photo loads, fails or was never
  /// uploaded. Every state below fills exactly this, which is what keeps the
  /// list from re-flowing under a thumb as photos arrive.
  static const _photoSize = 96.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final text = appText(context);

    void add() {
      ref.read(cartControllerProvider.notifier).add(item, config);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(text.addedNamed(item.name)),
            duration: const Duration(milliseconds: 1200),
          ),
        );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Both routes into the basket now confirm the same way. Tapping the row
        // used to announce the dish and tapping the + beside it added silently,
        // so whether a guest believed the thing had worked depended on where
        // their thumb landed.
        onTap: add,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DishPhoto(url: item.imageUrl, size: _photoSize),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                // Sized by its content, with the photo well setting the floor.
                // A fixed height here would be clipped by a guest running their
                // phone at the 2x text this app honours — and the thing clipped
                // would be the price.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: _photoSize),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      if (item.prepMinutes > 0) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Flexible(
                              child: Text(
                                text.prepMinutes(item.prepMinutes),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      // The price is what a guest is deciding on, so it gets its
                      // own line and the brand colour rather than competing
                      // with the dish name for the same glance.
                      Text(
                        item.price.display,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.filled(
                onPressed: add,
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

/// A dish photograph, or an honest stand-in for one.
///
/// Three things had to be true and only one of them was: the well is always the
/// same size (it was), a photo that is still downloading does not show the
/// same "no photo" plate it will show if the download fails (it did), and the
/// image does not pop into place (it did). The middle one was the worst of the
/// three — a guest scrolling a menu on a slow connection saw a screen of
/// crossed-out plates and concluded the restaurant had no pictures.
class _DishPhoto extends StatelessWidget {
  const _DishPhoto({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget well({required Widget child}) => ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: SizedBox(width: size, height: size, child: child),
        );

    final url = this.url;
    if (url == null) return well(child: _NoPhoto(size: size));

    return well(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // Fades in over its own placeholder instead of replacing it in one
        // frame. `wasSynchronouslyLoaded` is the already-cached case — on a
        // second visit the photo is simply there, with no animation to sit
        // through.
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: AppMotion.of(context),
            curve: AppMotion.enter,
            child: child,
          );
        },
        // Still arriving: a plain tinted well, which reads as "coming" rather
        // than as "this dish has no picture".
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : ColoredBox(color: scheme.surfaceContainerHighest),
        // A dish with a broken photo is still a dish somebody wants to order;
        // it must not take the tile down with it.
        errorBuilder: (_, __, ___) => _NoPhoto(size: size),
      ),
    );
  }
}

class _NoPhoto extends StatelessWidget {
  const _NoPhoto({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.restaurant_rounded,
        size: size * 0.36,
        color: scheme.outline,
      ),
    );
  }
}
