import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rms_core/rms_core.dart';
import '../../orders/data/order_repository.dart';
import '../application/settle_controller.dart';
import 'receipt_sheet.dart';

/// The bill: what is owed, how it is being paid, and closing it.
///
/// Everything shown here is the server's arithmetic, not the app's. The draft
/// ticket predicts a total so a waiter can quote one; this screen reports the
/// figure the guest is actually charged and the ledger is actually posted from.
class BillScreen extends ConsumerWidget {
  const BillScreen({super.key, required this.tableId, this.tableCode});

  final String tableId;
  final String? tableCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(tableOrderProvider(tableId));
    final title = tableCode == null ? 'Bill' : 'Bill · Table $tableCode';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: orderAsync.when(
        loading: () => const LoadingView(message: 'Fetching the bill…'),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(tableOrderProvider(tableId)),
        ),
        data: (order) {
          if (order == null) {
            return const EmptyView(
              icon: Icons.receipt_long_outlined,
              title: 'No open bill',
              message: 'This table has nothing to settle.',
            );
          }
          return _BillBody(order: order);
        },
      ),
    );
  }
}

class _BillBody extends ConsumerWidget {
  const _BillBody({required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settle = ref.watch(settleControllerProvider(order.id));
    final controller = ref.read(settleControllerProvider(order.id).notifier);

    // A bill settled in this session is the authority over the fetch behind it.
    final current = settle.order ?? order;
    if (current.status == OrderStatus.settled) {
      return _SettledView(order: current);
    }

    if (!current.isOpen) {
      return EmptyView(
        icon: Icons.block_rounded,
        title: 'This bill is ${current.status.label.toLowerCase()}',
        message: 'It cannot be settled. Ask a manager if that looks wrong.',
      );
    }

    final due = current.totals.total;
    final tender = settle.tenderFor(due);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            children: [
              _OrderLines(order: current),
              _TotalsBlock(totals: current.totals),
              const Divider(height: 1),
              _SplitBar(
                ways: tender.payments.length,
                onSplit: (ways) => controller.splitEvenly(ways, due),
              ),
              for (var index = 0; index < tender.payments.length; index++)
                _PaymentRow(
                  key: ValueKey('tender-$index-${tender.payments.length}'),
                  payment: tender.payments[index],
                  canRemove: tender.payments.length > 1,
                  onMethod: (method) =>
                      controller.setMethod(index, method, due),
                  onAmount: (amount) =>
                      controller.setAmount(index, amount, due),
                  onRemove: () => controller.removePayment(index, due),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: TextButton.icon(
                  onPressed: () => controller.addPayment(due),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Another payment'),
                ),
              ),
              if (tender.payments.any((p) => p.method.takesOverTender))
                _CashChange(
                  due: due,
                  received: settle.cashReceived,
                  change: settle.changeFor(tender),
                  onChanged: controller.setCashReceived,
                ),
              if (settle.error != null)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    settle.error!.message,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
        _SettleBar(
          order: current,
          tender: tender,
          isSettling: settle.isSettling,
          onSettle: () => controller.settle(current),
          onViewBill: () => ReceiptSheet.show(context, current),
        ),
      ],
    );
  }
}

class _OrderLines extends StatelessWidget {
  const _OrderLines({required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  order.orderNo.isEmpty ? 'Bill' : order.orderNo,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              StatusBadge(
                label: order.status.label,
                color: order.status.color,
                icon: order.status.icon,
              ),
            ],
          ),
        ),
        for (final line in order.lines)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text('${line.qty}×',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ),
                Expanded(child: Text(line.name)),
                Text(line.lineTotal.display),
              ],
            ),
          ),
      ],
    );
  }
}

class _TotalsBlock extends StatelessWidget {
  const _TotalsBlock({required this.totals});

  final OrderTotals totals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget row(String label, Money amount, {bool emphasise = false}) {
      final style = emphasise
          ? theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)
          : theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(label, style: style), Text(amount.display, style: style)],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          row('Subtotal', totals.subtotal),
          if (!totals.discount.isZero) row('Discount', totals.discount),
          if (!totals.tax.isZero) row('Tax', totals.tax),
          if (!totals.serviceCharge.isZero)
            row('Service charge', totals.serviceCharge),
          if (!totals.tip.isZero) row('Tip', totals.tip),
          if (!totals.rounding.isZero) row('Rounding', totals.rounding),
          const Divider(),
          row('Total due', totals.total, emphasise: true),
        ],
      ),
    );
  }
}

/// "Split it three ways" — the only split the API supports, since a settle
/// takes a list of payments rather than producing separate bills.
class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.ways, required this.onSplit});

  final int ways;
  final ValueChanged<int> onSplit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Text('Split', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(width: AppSpacing.md),
          for (final n in const [1, 2, 3, 4])
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                selected: ways == n,
                onSelected: (_) => onSplit(n),
                label: Text(n == 1 ? 'No' : '$n'),
              ),
            ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatefulWidget {
  const _PaymentRow({
    super.key,
    required this.payment,
    required this.canRemove,
    required this.onMethod,
    required this.onAmount,
    required this.onRemove,
  });

  final Payment payment;
  final bool canRemove;
  final ValueChanged<PaymentMethod> onMethod;
  final ValueChanged<Money> onAmount;
  final VoidCallback onRemove;

  @override
  State<_PaymentRow> createState() => _PaymentRowState();
}

class _PaymentRowState extends State<_PaymentRow> {
  late final TextEditingController _amount =
      TextEditingController(text: widget.payment.amount.amountText);

  @override
  void didUpdateWidget(_PaymentRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only overwrite the field when the model moved somewhere the text does not
    // already describe — otherwise an even split would fight the waiter's
    // cursor as they type.
    final typed = Money.tryParse(_amount.text, widget.payment.amount.currency);
    if (typed != widget.payment.amount) {
      _amount.text = widget.payment.amount.amountText;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<PaymentMethod>(
              initialValue: widget.payment.method,
              decoration: const InputDecoration(
                labelText: 'Method',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: [
                for (final method in PaymentMethod.values)
                  DropdownMenuItem(
                    value: method,
                    child: Row(
                      children: [
                        Icon(method.icon, size: 18),
                        const SizedBox(width: AppSpacing.sm),
                        Text(method.label),
                      ],
                    ),
                  ),
              ],
              onChanged: (method) {
                if (method != null) widget.onMethod(method);
              },
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 3,
            child: TextField(
              controller: _amount,
              textAlign: TextAlign.end,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: 'Amount',
                isDense: true,
                prefixText: '${widget.payment.amount.currency} ',
                border: const OutlineInputBorder(),
              ),
              onChanged: (text) {
                final parsed =
                    Money.tryParse(text, widget.payment.amount.currency);
                // Unparseable text leaves the model alone: clearing the field
                // to retype must not silently zero the tender.
                if (parsed != null) widget.onAmount(parsed);
              },
            ),
          ),
          IconButton(
            onPressed: widget.canRemove ? widget.onRemove : null,
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Remove this payment',
          ),
        ],
      ),
    );
  }
}

/// Change owed on a cash bill.
///
/// Deliberately separate from the tender: what the server is told is what was
/// applied to the bill, never the note the guest handed over. Mixing the two
/// would post a sale larger than the bill.
class _CashChange extends StatelessWidget {
  const _CashChange({
    required this.due,
    required this.received,
    required this.change,
    required this.onChanged,
  });

  final Money due;
  final Money? received;
  final Money? change;
  final ValueChanged<Money?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  textAlign: TextAlign.end,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Cash given (optional)',
                    isDense: true,
                    prefixText: '${due.currency} ',
                    border: const OutlineInputBorder(),
                    helperText: 'Working out only — not sent to the server',
                  ),
                  onChanged: (text) =>
                      onChanged(Money.tryParse(text, due.currency)),
                ),
              ),
            ],
          ),
          if (change != null && !change!.isZero)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Change due', style: theme.textTheme.titleMedium),
                  Text(
                    change!.display,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SettleBar extends StatelessWidget {
  const _SettleBar({
    required this.order,
    required this.tender,
    required this.isSettling,
    required this.onSettle,
    required this.onViewBill,
  });

  final OrderDetail order;
  final Tender tender;
  final bool isSettling;
  final VoidCallback onSettle;
  final VoidCallback onViewBill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final balanced = tender.isBalanced;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!balanced)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  // Naming the gap beats a dead button with no explanation.
                  tender.isShort
                      ? '${tender.outstanding.display} still to pay'
                      : '${tender.over.display} more than the bill',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: AppSizes.primaryActionHeight,
                    child: OutlinedButton.icon(
                      onPressed: onViewBill,
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('View bill'),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: AppSizes.primaryActionHeight,
                    child: FilledButton.icon(
                      onPressed: balanced && !isSettling ? onSettle : null,
                      icon: isSettling
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(
                        isSettling
                            ? 'Settling…'
                            : 'Settle ${tender.due.display}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettledView extends StatelessWidget {
  const _SettledView({required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 72, color: AppStatusColors.available),
            const SizedBox(height: AppSpacing.lg),
            Text('Bill settled', style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              order.orderNo.isEmpty
                  ? order.totals.total.display
                  : '${order.orderNo} · ${order.totals.total.display}',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: () => ReceiptSheet.show(context, order),
              icon: const Icon(Icons.print_outlined),
              label: const Text('Receipt'),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              // The table's own status is the manager's to change; the app does
              // not claim to have freed it.
              'The table is free once it has been cleared down.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
