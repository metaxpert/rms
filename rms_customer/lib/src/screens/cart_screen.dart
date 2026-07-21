import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import 'track_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  String _channel = 'DELIVERY';
  final _address = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Cart.instance.addListener(_onCart);
  }

  @override
  void dispose() {
    Cart.instance.removeListener(_onCart);
    _address.dispose();
    super.dispose();
  }

  void _onCart() => setState(() {});

  Future<void> _place() async {
    final cart = Cart.instance;
    if (cart.isEmpty) return;
    if (_channel == 'DELIVERY' && _address.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a delivery address.')));
      return;
    }
    setState(() => _busy = true);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final created = await Api.instance.post('/restaurant/orders', {'channel': _channel, 'guestCount': 1});
      final orderId = (created as Map<String, dynamic>)['id'] as String;
      final items = cart.lines.entries.map((e) => {'itemId': e.key.id, 'qty': e.value}).toList();
      await Api.instance.post('/restaurant/orders/$orderId/items', {'items': items});
      await Api.instance.post('/restaurant/orders/$orderId/place', {});
      cart.clear();
      nav.pushReplacement(MaterialPageRoute(builder: (_) => TrackScreen(orderId: orderId, address: _address.text.trim())));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Cart.instance;
    final lines = cart.lines.entries.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Your order')),
      body: cart.isEmpty
          ? const Center(child: Text('Your basket is empty.', style: TextStyle(color: Colors.black54)))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  child: Column(
                    children: [
                      for (final e in lines)
                        ListTile(
                          leading: FoodImage(url: e.key.imageUrl, name: e.key.name, size: 44),
                          title: Text(e.key.name),
                          subtitle: Text(e.key.price.formatted),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => cart.remove(e.key)),
                              Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w700)),
                              IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => cart.add(e.key)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text('How would you like it?', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _channelChoice('DELIVERY', 'Delivery', Icons.delivery_dining)),
                    const SizedBox(width: 10),
                    Expanded(child: _channelChoice('TAKEAWAY', 'Takeaway', Icons.shopping_bag_outlined)),
                  ],
                ),
                if (_channel == 'DELIVERY') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _address,
                    decoration: const InputDecoration(labelText: 'Delivery address', prefixIcon: Icon(Icons.location_on_outlined)),
                    maxLines: 2,
                  ),
                ],
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _row('Subtotal', Money.fmt(cart.subtotalMinor(), cart.currency), muted: true),
                        _row('Tax (16%)', Money.fmt(cart.taxMinor(), cart.currency), muted: true),
                        const Divider(),
                        _row('Total', Money.fmt(cart.totalMinor(), cart.currency), bold: true),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: _busy ? null : _place,
                  child: _busy
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Place order · ${Money.fmt(cart.totalMinor(), cart.currency)}'),
                ),
              ),
            ),
    );
  }

  Widget _channelChoice(String value, String label, IconData icon) {
    final on = _channel == value;
    return InkWell(
      onTap: () => setState(() => _channel = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: on ? AppTheme.primary.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? AppTheme.primary : const Color(0xFFEBE3D8), width: on ? 1.6 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: on ? AppTheme.primary : Colors.black45),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: on ? AppTheme.primary : Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, bool muted = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: muted ? Colors.black54 : Colors.black, fontWeight: bold ? FontWeight.w800 : FontWeight.w400, fontSize: bold ? 17 : 14)),
            Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: bold ? 17 : 14)),
          ],
        ),
      );
}
