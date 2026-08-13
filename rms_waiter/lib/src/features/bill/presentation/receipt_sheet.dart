import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rms_core/rms_core.dart';
import '../../../l10n/app_text.dart';
import '../../orders/data/order_repository.dart';

/// The slip, exactly as the printer will render it.
///
/// The layout is the SERVER's — the same document the thermal printer receives.
/// Re-laying it out here would drift from the paper, and the paper is the tax
/// invoice. So this is a monospace transcription and nothing more.
class ReceiptSheet extends ConsumerStatefulWidget {
  const ReceiptSheet({super.key, required this.order});

  final OrderDetail order;

  static Future<void> show(BuildContext context, OrderDetail order) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => ReceiptSheet(order: order),
      );

  @override
  ConsumerState<ReceiptSheet> createState() => _ReceiptSheetState();
}

class _ReceiptSheetState extends ConsumerState<ReceiptSheet> {
  String? _text;
  ApiException? _error;
  bool _queueing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      // 32 columns is the 58 mm layout — the one that stays legible on a phone.
      final text = await ref
          .read(orderRepositoryProvider)
          .receipt(widget.order.id, charsPerLine: 32);
      if (mounted) setState(() => _text = text ?? '');
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _queue({required bool reprint}) async {
    setState(() => _queueing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(orderRepositoryProvider).queuePrint(
            orderId: widget.order.id,
            reprint: reprint,
            // A first print is idempotent — a retry after a timeout must not
            // spool two slips. A REPRINT is a deliberate second copy, so it
            // gets a fresh key from the client every time.
            idempotencyKey: reprint ? null : 'print:${widget.order.id}',
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            reprint ? appText(context).reprintQueued : appText(context).printQueued,
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _queueing = false);
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final order = widget.order;
    final settled = order.status == OrderStatus.settled;
    // `restaurant:print` is one of the eight named permissions. Gated so a
    // waiter is not handed a button that comes back 403 while a guest waits.
    final mayPrint = ref.watch(permissionsProvider).canPrint;
    final text = appText(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              order.orderNo.isEmpty ? text.bill : order.orderNo,
              style: theme.textTheme.titleMedium,
            ),
            if (!settled)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  // A slip for an unsettled bill is not a tax invoice, and a
                  // guest handed one as if it were has been misled.
                  text.proFormaWarning,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Flexible(child: _body(context)),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (settled && mayPrint)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _queueing ? null : () => _queue(reprint: true),
                      icon: const Icon(Icons.replay_rounded),
                      label: Text(text.reprint),
                    ),
                  ),
                if (settled && mayPrint) const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _queueing || _text == null || !mayPrint
                        ? null
                        : () => _queue(reprint: false),
                    icon: const Icon(Icons.print_outlined),
                    label: Text(
                      !mayPrint
                          ? text.printingNotAllowed
                          : settled
                              ? text.print
                              : text.printProForma,
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

  Widget _body(BuildContext context) {
    final error = _error;
    if (error != null) {
      return ErrorView(error: error, onRetry: _load);
    }
    final text = _text;
    if (text == null) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: LoadingView(),
      );
    }
    if (text.isEmpty) {
      return EmptyView(
        icon: Icons.receipt_long_outlined,
        title: appText(context).emptySlipTitle,
        message: appText(context).emptySlipMessage,
      );
    }

    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: SelectableText(
          text,
          // Monospace or the server's column alignment is meaningless.
          style: const TextStyle(
            fontFamily: 'monospace',
            fontFamilyFallback: ['Courier', 'RobotoMono'],
            fontSize: 12,
            height: 1.35,
          ),
          onTap: () {
            Clipboard.setData(ClipboardData(text: text));
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                  SnackBar(content: Text(appText(context).billCopied)));
          },
        ),
      ),
    );
  }
}
