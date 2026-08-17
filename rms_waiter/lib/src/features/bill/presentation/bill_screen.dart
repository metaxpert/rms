import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rms_core/rms_core.dart';
import '../../../l10n/app_text.dart';
import '../../orders/data/order_repository.dart';
import '../application/settle_controller.dart';
import 'receipt_sheet.dart';

/// The bill: what is owed, how it is being paid, and closing it.
///
/// Everything shown here is the server's arithmetic, not the app's. The draft
/// ticket predicts a total so a waiter can quote one; this screen reports the
/// figure the guest is actually charged and the ledger is actually posted from.
class BillScreen extends ConsumerStatefulWidget {
  const BillScreen({super.key, required this.tableId, this.tableCode});

  final String tableId;
  final String? tableCode;

  @override
  ConsumerState<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends ConsumerState<BillScreen> {
  /// The bill this screen is about, remembered once seen.
  ///
  /// Settling closes the order, so the very next read of "the open order for
  /// this table" is correctly empty. Without holding on to the id, the screen
  /// would answer a successful settlement with "No open bill" — leaving a
  /// waiter who has just taken money with no idea whether it worked.
  String? _orderId;

  @override
  Widget build(BuildContext context) {
    final tableId = widget.tableId;
    final orderAsync = ref.watch(tableOrderProvider(tableId));
    final text = appText(context);
    final title = widget.tableCode == null
        ? text.bill
        : text.billForTable(widget.tableCode!);

    final fetched = orderAsync.valueOrNull;
    if (fetched != null) _orderId = fetched.id;

    final settled = _orderId == null
        ? null
        : ref.watch(settleControllerProvider(_orderId!)).order;

    // Shared by the settled view and the live bill, so backing out of a
    // settlement does not change the shape of the screen under the waiter.
    AppHeroHeader header({String? subtitle}) => AppHeroHeader(
          title: title,
          subtitle: subtitle,
          leading: HeroIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: text.back,
            onPressed: () => Navigator.of(context).pop(),
          ),
        );

    if (settled != null && settled.status == OrderStatus.settled) {
      return HeroScaffold(
        header:
            header(subtitle: settled.orderNo.isEmpty ? null : settled.orderNo),
        body: _SettledView(order: settled),
      );
    }

    return HeroScaffold(
      header: header(
        subtitle:
            fetched == null || fetched.orderNo.isEmpty ? null : fetched.orderNo,
      ),
      overlap: AppSpacing.md,
      body: orderAsync.when(
        loading: () => LoadingView(
          message: text.fetchingBill,
          skeleton: const _BillSkeleton(),
        ),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(tableOrderProvider(tableId)),
        ),
        data: (order) {
          if (order == null) {
            return EmptyView(
              icon: Icons.receipt_long_outlined,
              title: text.noOpenBillTitle,
              message: text.noOpenBillMessage,
            );
          }
          return _BillBody(order: order);
        },
      ),
    );
  }
}

/// The bill's shape while it is fetched: the priced lines, the totals block,
/// then the tender editor.
///
/// A waiter opens this standing at a table with the guest waiting, which is the
/// worst possible moment for a screen that says only that something is
/// happening.
class _BillSkeleton extends StatelessWidget {
  const _BillSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonGroup(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          for (var i = 0; i < 4; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                children: [
                  Skeleton(width: 28, height: 14),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(child: Skeleton.line(widthFactor: 0.6)),
                  SizedBox(width: AppSpacing.sm),
                  Skeleton(width: 72, height: 14),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          const Skeleton.box(height: 96),
          const SizedBox(height: AppSpacing.lg),
          const Skeleton.box(height: 72),
        ],
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
    final text = appText(context);
    final shared = strings(context);

    // A bill settled in this session is the authority over the fetch behind it.
    // The SETTLED case is handled a level up, in [BillScreen], because by then
    // the fetch has no open order to hand down at all.
    final current = settle.order ?? order;

    if (!current.isOpen) {
      return EmptyView(
        icon: Icons.block_rounded,
        title: text.billIsStatus(current.status.labelIn(shared).toLowerCase()),
        message: text.billCannotSettle,
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
                  label: Text(text.anotherPayment),
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
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
        _SettleBar(
          order: current,
          tender: tender,
          isSettling: settle.isSettling,
          onSettle: () => controller.settle(current, text),
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
                label: order.status.labelIn(strings(context)),
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
    final text = appText(context);

    Widget row(String label, Money amount, {bool emphasise = false}) {
      final style = emphasise
          ? theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)
          : theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: style),
            Text(amount.display, style: style)
          ],
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
          row(text.subtotal, totals.subtotal),
          if (!totals.discount.isZero) row(text.discount, totals.discount),
          if (!totals.tax.isZero) row(text.tax, totals.tax),
          if (!totals.serviceCharge.isZero)
            row(text.serviceCharge, totals.serviceCharge),
          if (!totals.tip.isZero) row(text.tip, totals.tip),
          if (!totals.rounding.isZero) row(text.rounding, totals.rounding),
          const Divider(),
          row(text.totalDue, totals.total, emphasise: true),
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
          Text(appText(context).split,
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(width: AppSpacing.md),
          for (final n in const [1, 2, 3, 4])
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                selected: ways == n,
                onSelected: (_) => onSplit(n),
                label: Text(n == 1 ? appText(context).splitNone : '$n'),
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
              decoration: InputDecoration(
                labelText: appText(context).paymentMethod,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final method in PaymentMethod.values)
                  DropdownMenuItem(
                    value: method,
                    child: Row(
                      children: [
                        Icon(method.icon, size: 18),
                        const SizedBox(width: AppSpacing.sm),
                        Text(method.labelIn(strings(context))),
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
                labelText: appText(context).paymentAmount,
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
            tooltip: appText(context).removePayment,
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
    final text = appText(context);

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
                    labelText: text.cashGiven,
                    isDense: true,
                    prefixText: '${due.currency} ',
                    border: const OutlineInputBorder(),
                    helperText: text.cashGivenHelper,
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
                  Text(text.changeDue, style: theme.textTheme.titleMedium),
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
    final text = appText(context);
    final balanced = tender.isBalanced;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          border:
              Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
          // Lifted off the list it is pinned over, so the bill scrolling
          // underneath reads as passing behind the bar rather than ending at it.
          boxShadow: AppElevation.lift(theme.brightness),
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
                      ? text.stillToPay(tender.outstanding.display)
                      : text.moreThanBill(tender.over.display),
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
                      label: Text(text.viewBill),
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
                            ? text.settling
                            : text.settleAmount(tender.due.display),
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
    final text = appText(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 72,
              color: context.statusFill(AppStatusColors.available),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(text.billSettled, style: theme.textTheme.headlineSmall),
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
              label: Text(text.receipt),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              // The table's own status is the manager's to change; the app does
              // not claim to have freed it.
              text.tableFreeWhenCleared,
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
