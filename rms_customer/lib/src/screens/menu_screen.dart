import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import 'cart_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  List<MenuItem>? _items;
  Object? _error;
  String? _cat;

  @override
  void initState() {
    super.initState();
    _load();
    Cart.instance.addListener(_onCart);
  }

  @override
  void dispose() {
    Cart.instance.removeListener(_onCart);
    super.dispose();
  }

  void _onCart() => setState(() {});

  Future<void> _load() async {
    try {
      final data = await Api.instance.get('/restaurant/items') as List;
      final list = data.map((e) => MenuItem.from(e as Map<String, dynamic>)).where((m) => m.available).toList();
      if (mounted) setState(() { _items = list; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final cats = items == null ? <String>[] : (<String>{for (final m in items) m.category ?? 'Other'}.toList());
    final shown = items == null ? <MenuItem>[] : items.where((m) => _cat == null || (m.category ?? 'Other') == _cat).toList();
    final cart = Cart.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Karahi Point'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: items == null
          ? (_error != null ? Center(child: Text('$_error', style: const TextStyle(color: Colors.black54))) : const Center(child: CircularProgressIndicator()))
          : Column(
              children: [
                SizedBox(
                  height: 46,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    children: [
                      _chip('All', _cat == null, () => setState(() => _cat = null)),
                      for (final c in cats) _chip(c, _cat == c, () => setState(() => _cat = c)),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.74,
                    ),
                    itemCount: shown.length,
                    itemBuilder: (context, i) => _card(shown[i]),
                  ),
                ),
              ],
            ),
      floatingActionButton: cart.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen())),
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.shopping_bag),
              label: Text('${cart.count} item${cart.count == 1 ? '' : 's'}  ·  ${Money.fmt(cart.subtotalMinor(), cart.currency)}'),
            ),
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: on,
          onSelected: (_) => onTap(),
          selectedColor: AppTheme.primary,
          labelStyle: TextStyle(color: on ? Colors.white : Colors.black87, fontWeight: FontWeight.w600, fontSize: 12),
          backgroundColor: Colors.white,
        ),
      );

  Widget _card(MenuItem m) {
    final qty = Cart.instance.qtyOf(m);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: FoodImage(url: m.imageUrl, name: m.name, radius: 0)),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(m.price.formatted, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primary)),
                    qty == 0
                        ? _AddButton(onTap: () => Cart.instance.add(m))
                        : _Stepper(qty: qty, onAdd: () => Cart.instance.add(m), onRemove: () => Cart.instance.remove(m)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: const Icon(Icons.add, color: AppTheme.primary, size: 20),
        ),
      );
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.qty, required this.onAdd, required this.onRemove});
  final int qty;
  final VoidCallback onAdd, onRemove;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _btn(Icons.remove, onRemove),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('$qty', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
            _btn(Icons.add, onAdd),
          ],
        ),
      );

  Widget _btn(IconData i, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(padding: const EdgeInsets.all(5), child: Icon(i, color: Colors.white, size: 18)),
      );
}
