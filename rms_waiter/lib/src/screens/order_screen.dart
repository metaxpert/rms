import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import 'receipt_sheet.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key, required this.orderId, this.tableCode});
  final String orderId;
  final String? tableCode;

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  OrderDetail? _order;
  List<MenuItem> _menu = [];
  String? _cat;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final menu = await Api.instance.get('/restaurant/items') as List;
      _menu = menu.map((e) => MenuItem.from(e as Map<String, dynamic>)).where((m) => m.available).toList();
      await _reload();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reload() async {
    final o = await Api.instance.get('/restaurant/orders/${widget.orderId}');
    if (mounted) setState(() => _order = OrderDetail.from(o as Map<String, dynamic>));
  }

  Future<void> _run(Future<void> Function() action, {String? ok}) async {
    setState(() => _busy = true);
    try {
      await action();
      await _reload();
      if (ok != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok), duration: const Duration(milliseconds: 900)));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addItem(MenuItem m) => _run(
        () => Api.instance.post('/restaurant/orders/${widget.orderId}/items', {
          'items': [
            {'itemId': m.id, 'qty': 1}
          ]
        }),
        ok: '${m.name} added',
      );

  /// Scan-to-add. A restaurant's scanner is a keyboard wedge, so this is a plain text field that
  /// submits on Enter — it works with hardware scanners, and stays usable by typing when one dies.
  Future<void> _scanAdd(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;
    await _run(
      () => Api.instance.post('/restaurant/orders/${widget.orderId}/scan-add', {'code': trimmed, 'qty': 1}),
      ok: 'Scanned in',
    );
  }

  Future<void> _openScanner() async {
    final controller = TextEditingController();
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Scan a barcode', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Point the scanner at the product, or type the code.',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.qr_code_scanner),
                    hintText: '8964000112233',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (v) => Navigator.pop(sheetContext, v),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                  onPressed: () => Navigator.pop(sheetContext, controller.text),
                  child: const Text('Add to ticket'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    controller.dispose();
    if (code != null) await _scanAdd(code);
  }

  Future<void> _removeLine(OrderLine l) =>
      _run(() => Api.instance.del('/restaurant/orders/${widget.orderId}/items/${l.id}'), ok: 'Removed');

  Future<void> _place() => _run(() => Api.instance.post('/restaurant/orders/${widget.orderId}/place', {}), ok: 'Order placed');
  Future<void> _confirm() => _run(() => Api.instance.post('/restaurant/orders/${widget.orderId}/confirm', {}), ok: 'Sent to kitchen');

  Future<void> _settle() async {
    final order = _order!;
    final method = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Settle ${order.orderNo} · ${order.total.formatted}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            for (final m in const ['CASH', 'CARD', 'WALLET', 'ONLINE'])
              ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: Text(m),
                onTap: () => Navigator.pop(context, m),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (method == null) return;
    await _run(
      () => Api.instance.post('/restaurant/orders/${widget.orderId}/settle', {
        'payments': [
          {'method': method, 'amountMinor': order.total.amountMinor}
        ]
      }),
      ok: 'Bill settled',
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final title = widget.tableCode != null ? 'Table ${widget.tableCode}' : (order?.orderNo ?? 'Order');
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (order != null && order.isDraft)
            IconButton(
              tooltip: 'Scan a barcode',
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: _busy ? null : _openScanner,
            ),
          if (order != null)
            IconButton(
              tooltip: 'Bill',
              icon: const Icon(Icons.receipt_long_outlined),
              onPressed: () => ReceiptSheet.show(context, orderId: widget.orderId, orderNo: order.orderNo, settled: order.isSettled),
            ),
          if (order != null) Padding(padding: const EdgeInsets.only(right: 12), child: Center(child: StatusChip(order.status))),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.primary,
          indicatorColor: AppTheme.primary,
          tabs: [
            const Tab(text: 'Menu'),
            Tab(text: 'Ticket${order != null && order.items.isNotEmpty ? ' (${order.items.length})' : ''}'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : TabBarView(controller: _tabs, children: [_menuTab(), _ticketTab()]),
    );
  }

  // ── Menu grid ──────────────────────────────────────────────────────────────
  Widget _menuTab() {
    final cats = <String>{for (final m in _menu) m.category ?? 'Other'}.toList();
    final shown = _menu.where((m) => _cat == null || (m.category ?? 'Other') == _cat).toList();
    final canAdd = _order != null && _order!.isDraft;
    return Column(
      children: [
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              _catChip('All', _cat == null, () => setState(() => _cat = null)),
              for (final c in cats) _catChip(c, _cat == c, () => setState(() => _cat = c)),
            ],
          ),
        ),
        if (!canAdd)
          Container(
            width: double.infinity,
            color: const Color(0xFFFBEBC8),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Text(
              _order!.isSettled ? 'This bill is settled.' : 'Order already sent — start a new order to add items.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF8A5A20)),
            ),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            itemCount: shown.length,
            itemBuilder: (context, i) {
              final m = shown[i];
              return Opacity(
                opacity: canAdd && !_busy ? 1 : 0.5,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: canAdd && !_busy ? () => _addItem(m) : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: FoodImage(url: m.imageUrl, name: m.name, radius: 0)),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 2),
                              Text(m.price.formatted, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primary, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _catChip(String label, bool on, VoidCallback onTap) => Padding(
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

  // ── Ticket / cart ──────────────────────────────────────────────────────────
  Widget _ticketTab() {
    final order = _order;
    if (order == null) return const SizedBox();
    final editable = order.isDraft;
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text('${order.orderNo} · ${order.channel.replaceAll('_', ' ').toLowerCase()} · ${order.guestCount} guests',
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ),
        Expanded(
          child: order.items.isEmpty
              ? const Center(child: Text('No items yet.\nAdd dishes from the Menu tab.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black45)))
              : ListView.separated(
                  itemCount: order.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final l = order.items[i];
                    return ListTile(
                      leading: Text('${l.qty}×', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
                      title: Text(l.name),
                      subtitle: Text(l.unitPrice.formatted, style: const TextStyle(fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l.lineTotal.formatted, style: const TextStyle(fontWeight: FontWeight.w700)),
                          if (editable)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.black38),
                              onPressed: _busy ? null : () => _removeLine(l),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        _totalsAndActions(order),
      ],
    );
  }

  Widget _totalsAndActions(OrderDetail order) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEBE3D8))),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _totalRow('Subtotal', order.subtotal.formatted, muted: true),
          _totalRow('Tax', order.tax.formatted, muted: true),
          const SizedBox(height: 2),
          _totalRow('Total', order.total.formatted, bold: true),
          const SizedBox(height: 12),
          Row(
            children: [
              if (order.isDraft)
                Expanded(child: FilledButton(onPressed: _busy || order.items.isEmpty ? null : _place, child: const Text('Place order'))),
              if (order.status == 'PLACED')
                Expanded(child: FilledButton(onPressed: _busy ? null : _confirm, child: const Text('Send to kitchen'))),
              if (order.canSettle)
                Expanded(child: FilledButton(onPressed: _busy ? null : _settle, child: const Text('Settle bill'))),
              if (order.isSettled) ...[
                const Expanded(child: Center(child: Text('Paid ✓', style: TextStyle(color: Color(0xFF1B7A4B), fontWeight: FontWeight.w700)))),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => ReceiptSheet.show(context, orderId: widget.orderId, orderNo: order.orderNo, settled: true),
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: const Text('Print bill'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value, {bool bold = false, bool muted = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: muted ? Colors.black54 : Colors.black, fontWeight: bold ? FontWeight.w800 : FontWeight.w400, fontSize: bold ? 17 : 14)),
            Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: bold ? 17 : 14)),
          ],
        ),
      );
}
