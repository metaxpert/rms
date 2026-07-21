import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import 'menu_screen.dart';

class TrackScreen extends StatefulWidget {
  const TrackScreen({super.key, required this.orderId, this.address});
  final String orderId;
  final String? address;

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  TrackOrder? _order;
  Object? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final o = await Api.instance.get('/restaurant/orders/${widget.orderId}') as Map<String, dynamic>;
      Map<String, dynamic>? d;
      if (o['channel'] == 'DELIVERY') {
        final all = await Api.instance.get('/restaurant/deliveries') as List;
        for (final e in all) {
          if ((e as Map<String, dynamic>)['orderId'] == widget.orderId) { d = e; break; }
        }
      }
      if (mounted) setState(() { _order = TrackOrder.from(o, d); _error = null; });
    } catch (e) {
      if (mounted && !silent) setState(() => _error = e);
    }
  }

  /// The customer-facing progress steps for this order, and which are done.
  List<({String label, IconData icon, bool done, bool active})> _steps(TrackOrder o) {
    final isDelivery = o.channel == 'DELIVERY';
    final s = o.status;
    int stage; // 0 placed, 1 kitchen, 2 ready, 3 out/pickup, 4 done
    if (o.isSettledOrClosed) {
      stage = 4;
    } else if (o.delivery?.status == 'DELIVERED') {
      stage = 4;
    } else if (o.delivery?.status == 'PICKED_UP' || o.delivery?.status == 'EN_ROUTE' || s == 'SERVED') {
      stage = 3;
    } else if (s == 'READY') {
      stage = 2;
    } else if (s == 'CONFIRMED' || s == 'IN_PROGRESS') {
      stage = 1;
    } else {
      stage = 0;
    }
    final steps = <({String label, IconData icon})>[
      (label: 'Order placed', icon: Icons.receipt_long),
      (label: 'In the kitchen', icon: Icons.soup_kitchen),
      (label: 'Ready', icon: Icons.check_circle_outline),
      (label: isDelivery ? 'Out for delivery' : 'Ready for pickup', icon: isDelivery ? Icons.delivery_dining : Icons.storefront),
      (label: isDelivery ? 'Delivered' : 'Picked up', icon: Icons.emoji_food_beverage),
    ];
    return [
      for (var i = 0; i < steps.length; i++)
        (label: steps[i].label, icon: steps[i].icon, done: i < stage, active: i == stage),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track order'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const MenuScreen()), (_) => false),
            child: const Text('Done'),
          ),
        ],
      ),
      body: o == null
          ? (_error != null ? Center(child: Text('$_error')) : const Center(child: CircularProgressIndicator()))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  Expanded(child: Text(o.orderNo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                  const LiveDot(),
                ]),
                const SizedBox(height: 2),
                Text('${o.channel.replaceAll('_', ' ').toLowerCase()} · ${o.total.formatted}', style: const TextStyle(color: Colors.black54)),
                if (o.delivery?.etaMinutes != null) ...[
                  const SizedBox(height: 2),
                  Text('Estimated arrival in ${o.delivery!.etaMinutes} min', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(children: [for (final s in _steps(o)) _step(s)]),
                  ),
                ),
                if (o.delivery != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.two_wheeler, color: AppTheme.primary),
                      title: Text('Rider · ${o.delivery!.deliveryNo}'),
                      subtitle: const Text('Have your OTP ready — the rider will ask for it.'),
                      trailing: StatusChip(o.delivery!.status),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text('Your items', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [for (final n in o.itemNames) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(n))],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _step(({String label, IconData icon, bool done, bool active}) s) {
    final color = s.done ? const Color(0xFF1B7A4B) : (s.active ? AppTheme.primary : Colors.black26);
    return ListTile(
      dense: true,
      leading: Icon(s.done ? Icons.check_circle : (s.active ? Icons.radio_button_checked : s.icon), color: color),
      title: Text(s.label, style: TextStyle(fontWeight: s.active ? FontWeight.w700 : FontWeight.w500, color: s.done || s.active ? Colors.black87 : Colors.black45)),
      trailing: s.active ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)) : null,
    );
  }
}
