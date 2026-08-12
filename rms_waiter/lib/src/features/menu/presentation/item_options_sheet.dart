import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rms_core/rms_core.dart';
import '../data/menu_repository.dart';

/// Configure one dish before it joins the ticket: options, quantity, and what
/// the kitchen should know.
///
/// Returns the [DraftLine] to add, or null if the waiter backed out.
Future<DraftLine?> showItemOptionsSheet(
  BuildContext context, {
  required MenuItem item,
  required RestaurantConfig config,
}) {
  return showModalBottomSheet<DraftLine>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _ItemOptionsSheet(item: item, config: config),
  );
}

class _ItemOptionsSheet extends ConsumerStatefulWidget {
  const _ItemOptionsSheet({required this.item, required this.config});

  final MenuItem item;
  final RestaurantConfig config;

  @override
  ConsumerState<_ItemOptionsSheet> createState() => _ItemOptionsSheetState();
}

class _ItemOptionsSheetState extends ConsumerState<_ItemOptionsSheet> {
  final _notes = TextEditingController();

  /// Chosen modifier ids per group.
  final Map<String, Set<String>> _selected = {};
  int _qty = 1;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _toggle(ModifierGroup group, Modifier modifier) {
    setState(() {
      final chosen = _selected.putIfAbsent(group.id, () => <String>{});
      final single = group.maxSelect == 1;

      if (chosen.contains(modifier.id)) {
        // A required single-choice group keeps its answer: un-picking would
        // leave the line in a state the waiter cannot submit, with no hint why.
        if (single && group.effectiveMinSelect > 0) return;
        chosen.remove(modifier.id);
        return;
      }

      if (single) {
        chosen
          ..clear()
          ..add(modifier.id);
        return;
      }

      final max = group.maxSelect;
      if (max != null && chosen.length >= max) return;
      chosen.add(modifier.id);
    });
  }

  /// The first group whose rules are not yet satisfied, if any.
  ModifierGroup? _unsatisfied(List<ModifierGroup> groups) {
    for (final group in groups) {
      final count = _selected[group.id]?.length ?? 0;
      if (count < group.effectiveMinSelect) return group;
    }
    return null;
  }

  List<DraftModifier> _chosenModifiers(List<ModifierGroup> groups) => [
        for (final group in groups)
          for (final modifier in group.modifiers)
            if (_selected[group.id]?.contains(modifier.id) ?? false)
              DraftModifier.from(modifier),
      ];

  DraftLine _lineFor(List<ModifierGroup> groups) => DraftLine.fromMenuItem(
        widget.item,
        config: widget.config,
        qty: _qty,
        modifiers: _chosenModifiers(groups),
        kitchenNotes: _notes.text,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = ref.watch(itemModifierGroupsProvider(widget.item.id));

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.item.name,
                          style: theme.textTheme.titleLarge,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      Text(
                        widget.item.price.display,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _QtyStepper(
                  qty: _qty,
                  onChanged: (qty) => setState(() => _qty = qty),
                ),
              ],
            ),
          ),
          Expanded(
            child: groups.when(
              loading: () => const LoadingView(message: 'Loading options…'),
              // Without the options we cannot know whether a required choice is
              // being skipped, so this is a hard stop rather than a warning.
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () =>
                    ref.invalidate(itemModifierGroupsProvider(widget.item.id)),
              ),
              data: (groups) => _Options(
                controller: scrollController,
                groups: groups,
                selected: _selected,
                notes: _notes,
                onToggle: _toggle,
              ),
            ),
          ),
          groups.maybeWhen(
            data: (groups) => _AddBar(
              line: _lineFor(groups),
              blockedBy: _unsatisfied(groups),
              onAdd: () => Navigator.of(context).pop(_lineFor(groups)),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _Options extends StatelessWidget {
  const _Options({
    required this.controller,
    required this.groups,
    required this.selected,
    required this.notes,
    required this.onToggle,
  });

  final ScrollController controller;
  final List<ModifierGroup> groups;
  final Map<String, Set<String>> selected;
  final TextEditingController notes;
  final void Function(ModifierGroup, Modifier) onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      children: [
        for (final group in groups) ...[
          Row(
            children: [
              Expanded(
                child: Text(group.name, style: theme.textTheme.titleMedium),
              ),
              Text(
                _ruleText(group),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: group.effectiveMinSelect > 0
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final modifier in group.selectable)
                FilterChip(
                  selected: selected[group.id]?.contains(modifier.id) ?? false,
                  onSelected: (_) => onToggle(group, modifier),
                  label: Text(
                    modifier.priceDelta.isZero
                        ? modifier.name
                        : '${modifier.name}  +${modifier.priceDelta.display}',
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        TextField(
          controller: notes,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Note for the kitchen',
            hintText: 'No chilli, well done, serve last…',
            prefixIcon: Icon(Icons.edit_note_rounded),
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  static String _ruleText(ModifierGroup group) {
    final min = group.effectiveMinSelect;
    final max = group.maxSelect;
    if (min > 0 && max == min) return 'Choose $min';
    if (min > 0) return 'Choose at least $min';
    if (max != null) return 'Up to $max';
    return 'Optional';
  }
}

/// The sheet's primary action, showing what it will add and what it costs.
class _AddBar extends StatelessWidget {
  const _AddBar({
    required this.line,
    required this.blockedBy,
    required this.onAdd,
  });

  final DraftLine line;

  /// The group still needing an answer, if any.
  final ModifierGroup? blockedBy;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocked = blockedBy;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (blocked != null) ...[
              Text(
                // Naming the group beats a greyed-out button with no
                // explanation, which reads as the app being broken.
                'Choose ${blocked.name.toLowerCase()} first',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.error),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            SizedBox(
              width: double.infinity,
              height: AppSizes.primaryActionHeight,
              child: FilledButton(
                onPressed: blocked == null ? onAdd : null,
                child: Text(
                  'Add ${line.qty} · ${line.taxable.display}',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.qty, required this.onChanged});

  final int qty;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          // 99 of one dish is a fat-finger, not an order; the cap stops a
          // stepper held down from reaching the kitchen.
          onPressed: qty > 1 ? () => onChanged(qty - 1) : null,
          icon: const Icon(Icons.remove_rounded),
          tooltip: 'One fewer',
        ),
        SizedBox(
          width: 48,
          child: Text(
            '$qty',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
        ),
        IconButton.filledTonal(
          onPressed: qty < 99 ? () => onChanged(qty + 1) : null,
          icon: const Icon(Icons.add_rounded),
          tooltip: 'One more',
        ),
      ],
    );
  }
}
