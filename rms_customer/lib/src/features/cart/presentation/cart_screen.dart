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
                    // An address is prose, not a name: sentence case, the
                    // address keyboard, and the platform's saved address
                    // offered rather than left to be retyped on a phone.
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.streetAddress,
                    autofillHints: const [AutofillHints.fullStreetAddress],
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: text.addressLabel,
                      hintText: text.addressHint,
                      // The themed decoration, not a bare OutlineInputBorder:
                      // this was the only field in the app that did not look
                      // like the rest of the app.
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: AppSpacing.xl),
                        child: Icon(Icons.location_on_outlined),
                      ),
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
                    // Shrinks rather than ellipsising. "Place o…" on the button
                    // that takes a guest's money is not an acceptable last
                    // resort; a couple of points smaller is.
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        checkout.isPlacing
                            ? text.sending
                            : checkout.pending != null
                                ? text.tryAgain
                                : text.placeOrder,
                        maxLines: 1,
                      ),
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
    final text = appText(context);

    // Two rows rather than one. The single row put a name, two 56dp buttons, a
    // quantity and a total side by side: on a 360-pixel phone that left about
    // ninety pixels for the dish, so "Chicken Karahi (Half)" arrived as
    // "Chicken…". The name now gets the full width and the controls get their
    // own line, where they are also easier to hit.
    final name = Text(line.name, style: theme.textTheme.titleSmall);
    final total = Text(
      line.taxable.display,
      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    );

    // Past about 1.4x, "Rs 2,202.84" alone is wider than a 360-pixel phone, so
    // the dish name has nowhere to go and the two collide. Stacking them is the
    // only honest answer: the figure must not be shrunk to fit — it is what the
    // guest is being charged — and the name must not be reduced to two letters.
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.4;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stacked) ...[
            name,
            const SizedBox(height: AppSpacing.xs),
            total,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: name),
                const SizedBox(width: AppSpacing.md),
                total,
              ],
            ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  line.unitPrice.display,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              _QtyStepper(
                qty: line.qty,
                onQty: onQty,
                removeTooltip: text.remove,
                fewerTooltip: text.oneFewer,
                moreTooltip: text.oneMore,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Minus, quantity, plus — as one bounded control.
///
/// Three loose `IconButton`s here cost the row its whole width at the 2x text
/// this app honours: their intrinsic size grows with the text scale, the price
/// beside them was flexed down to nothing, and the line rendered fourteen
/// hundred pixels tall. A stepper is a fixed piece of furniture, so it is built
/// as one and given a size it cannot exceed.
class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.qty,
    required this.onQty,
    required this.removeTooltip,
    required this.fewerTooltip,
    required this.moreTooltip,
  });

  final int qty;
  final ValueChanged<int>? onQty;
  final String removeTooltip;
  final String fewerTooltip;
  final String moreTooltip;

  /// Comfortably past Material's 48dp minimum: this is tapped repeatedly, on a
  /// phone, often one-handed.
  static const _button = 52.0;
  static const _readout = 44.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget step({
      required IconData icon,
      required String tooltip,
      required VoidCallback? onPressed,
    }) =>
        Tooltip(
          message: tooltip,
          child: Semantics(
            button: true,
            label: tooltip,
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: _button,
                height: _button,
                child: Icon(
                  icon,
                  size: 22,
                  color: onPressed == null
                      ? theme.colorScheme.outline
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          step(
            // The first tap down from one removes the line, so the icon says so
            // rather than leaving a guest to discover it.
            icon: qty > 1 ? Icons.remove_rounded : Icons.delete_outline_rounded,
            tooltip: qty > 1 ? fewerTooltip : removeTooltip,
            onPressed: onQty == null ? null : () => onQty!(qty - 1),
          ),
          SizedBox(
            width: _readout,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              maxLines: 1,
              style: theme.textTheme.titleMedium,
            ),
          ),
          step(
            icon: Icons.add_rounded,
            tooltip: moreTooltip,
            onPressed: onQty == null || qty >= 99 ? null : () => onQty!(qty + 1),
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
    // A segmented button sizes itself to its labels and will not shrink to fit.
    // "Delivery" and "Collection" plus their icons overflow a small phone once
    // the reader's text size passes about 1.6x, so it scales down rather than
    // clipping — still larger than the default, and still whole.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: SegmentedButton<OrderChannel>(
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
      ),
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
          children: [
            // The label yields, the figure never does. At the 2x text this app
            // honours, "Total" and "Rs 2,202.84" together are wider than a
            // 360-pixel phone, and an unflexed Row clips whichever it reaches
            // last — which is the amount.
            Flexible(child: Text(label, style: style)),
            const SizedBox(width: AppSpacing.md),
            Text(amount.display, style: style),
          ],
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
    final text = appText(context);

    return AppNotice(
      tone: NoticeTone.danger,
      title: text.checkoutFailedTitle,
      message: [
        checkout.error?.message ?? text.checkoutInterrupted,
        // Saying "nothing was ordered" would be a guess the kitchen could
        // contradict.
        if (checkout.orderExists) text.checkoutPartial,
      ].join('\n\n'),
      margin: const EdgeInsets.only(top: AppSpacing.lg),
      action: TextButton(
        onPressed: onDiscard,
        child: Text(text.startOrderAgain),
      ),
    );
  }
}
