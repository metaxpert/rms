import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rms_core/rms_core.dart';
import '../../../app/router/app_router.dart';
import '../../../l10n/app_text.dart';
import '../../checkout/application/checkout_controller.dart';
import '../../orders/data/customer_order_repository.dart';
import '../application/cart_controller.dart';

/// The basket, and placing the order.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  OrderChannel _channel = OrderChannel.delivery;
  final _address = TextEditingController();

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartControllerProvider);
    final controller = ref.read(cartControllerProvider.notifier);
    final config = ref.watch(menuCatalogueProvider).valueOrNull?.config;
    final checkout = ref.watch(checkoutControllerProvider);
    final text = appText(context);

    ref.listen(checkoutControllerProvider, (previous, next) {
      if (previous?.phase == next.phase) return;
      if (next.phase == CheckoutPhase.placed && next.orderId != null) {
        context.pushReplacement(
          Routes.track(next.orderId!),
          extra: next.addressAccepted ? null : _address.text.trim(),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(text.yourBasket)),
      body: cart.isEmpty
          ? EmptyView(
              icon: Icons.shopping_bag_outlined,
              title: text.basketEmptyTitle,
              message: text.basketEmptyMessage,
              action: FilledButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.restaurant_menu_rounded),
                label: Text(text.backToMenu),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                for (var index = 0; index < cart.lines.length; index++)
                  _CartLine(
                    line: cart.lines[index],
                    onQty: checkout.isPlacing
                        ? null
                        : (qty) => controller.setQty(index, qty),
                  ),
                const Divider(height: AppSpacing.xl),
                _ChannelPicker(
                  channel: _channel,
                  enabled: !checkout.isPlacing,
                  onChanged: (channel) => setState(() => _channel = channel),
                ),
                if (_channel.needsAddress) ...[
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _address,
                    enabled: !checkout.isPlacing,
                    minLines: 2,
                    maxLines: 3,
                    // Long enough for a Pakistani address with a landmark,
                    // bounded so a paste of somebody's whole life story does
                    // not become the order payload.
                    maxLength: 240,
                    decoration: InputDecoration(
                      labelText: text.addressLabel,
                      hintText: text.addressHint,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                if (config != null) _Totals(cart: cart, config: config),
                if (checkout.phase == CheckoutPhase.failed)
                  _CheckoutProblem(
                    checkout: checkout,
                    onDiscard: () =>
                        ref.read(checkoutControllerProvider.notifier).discard(),
                  ),
              ],
            ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: SizedBox(
                  height: AppSizes.primaryActionHeight,
                  child: FilledButton.icon(
                    onPressed: _canPlace(checkout) ? _place : null,
                    icon: checkout.isPlacing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      checkout.isPlacing
                          ? text.sending
                          : checkout.pending != null
                              ? text.tryAgain
                              : text.placeOrder,
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  bool _canPlace(CheckoutState checkout) {
    if (checkout.isPlacing) return false;
    // Delivery without an address is an order nobody can fulfil.
    if (_channel.needsAddress && _address.text.trim().isEmpty) return false;
    return true;
  }

  void _place() => ref.read(checkoutControllerProvider.notifier).place(
        cart: ref.read(cartControllerProvider),
        channel: _channel,
        address: _channel.needsAddress ? _address.text.trim() : null,
      );
}

class _CartLine extends StatelessWidget {
  const _CartLine({required this.line, required this.onQty});

  final DraftLine line;
  final ValueChanged<int>? onQty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name, style: theme.textTheme.titleSmall),
                Text(
                  line.unitPrice.display,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton.outlined(
            onPressed: onQty == null ? null : () => onQty!(line.qty - 1),
            icon: Icon(line.qty > 1
                ? Icons.remove_rounded
                : Icons.delete_outline_rounded),
            tooltip: line.qty > 1
                ? appText(context).oneFewer
                : appText(context).remove,
          ),
          SizedBox(
            width: 36,
            child: Text(
              '${line.qty}',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ),
          IconButton.outlined(
            onPressed: onQty == null || line.qty >= 99
                ? null
                : () => onQty!(line.qty + 1),
            icon: const Icon(Icons.add_rounded),
            tooltip: appText(context).oneMore,
          ),
          SizedBox(
            width: 92,
            child: Text(
              line.taxable.display,
              textAlign: TextAlign.end,
              style: theme.textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelPicker extends StatelessWidget {
  const _ChannelPicker({
    required this.channel,
    required this.enabled,
    required this.onChanged,
  });

  final OrderChannel channel;
  final bool enabled;
  final ValueChanged<OrderChannel> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<OrderChannel>(
      segments: [
        ButtonSegment(
          value: OrderChannel.delivery,
          icon: const Icon(Icons.delivery_dining_rounded),
          label: Text(appText(context).delivery),
        ),
        ButtonSegment(
          value: OrderChannel.takeaway,
          icon: const Icon(Icons.shopping_bag_outlined),
          label: Text(appText(context).collection),
        ),
      ],
      selected: {channel},
      onSelectionChanged:
          enabled ? (selection) => onChanged(selection.first) : null,
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.cart, required this.config});

  final Cart cart;
  final RestaurantConfig config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = appText(context);
    final totals = cart.totals(config);

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

    return Column(
      children: [
        row(text.subtotal, totals.subtotal),
        if (!totals.tax.isZero) row(text.tax, totals.tax),
        if (!totals.serviceCharge.isZero)
          row(text.serviceCharge, totals.serviceCharge),
        if (!totals.rounding.isZero) row(text.rounding, totals.rounding),
        const Divider(),
        row(text.total, totals.total, emphasise: true),
        const SizedBox(height: AppSpacing.xs),
        Text(
          // The restaurant re-prices every line when the order is placed. Saying
          // so is better than a guest arguing at a counter about a figure this
          // app quoted from a menu that had since changed.
          text.priceConfirmedNote,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _CheckoutProblem extends StatelessWidget {
  const _CheckoutProblem({required this.checkout, required this.onDiscard});

  final CheckoutState checkout;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = appText(context);

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text.checkoutFailedTitle,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            checkout.error?.message ?? text.checkoutInterrupted,
            style: theme.textTheme.bodySmall,
          ),
          if (checkout.orderExists) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              // Saying "nothing was ordered" would be a guess the kitchen could
              // contradict.
              text.checkoutPartial,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: onDiscard,
            child: Text(text.startOrderAgain),
          ),
        ],
      ),
    );
  }
}
