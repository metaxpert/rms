import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'order_screen.dart';

class TablesScreen extends StatefulWidget {
  const TablesScreen({super.key});
  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> {
  late Future<List<TableModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<TableModel>> _load() async {
    final data = await Api.instance.get('/restaurant/tables') as List;
    return data.map((e) => TableModel.from(e as Map<String, dynamic>)).toList();
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _openTable(TableModel t) async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      // Reuse an open order on this table if one exists, otherwise start a fresh one.
      final orders = await Api.instance.get('/restaurant/orders?tableId=${t.id}') as List;
      final open = orders.cast<Map<String, dynamic>>().where(
            (o) => !const ['CLOSED', 'VOID', 'SETTLED'].contains(o['status']),
          );
      String orderId;
      if (open.isNotEmpty) {
        orderId = open.first['id'] as String;
      } else {
        final created = await Api.instance.post('/restaurant/orders', {'channel': 'DINE_IN', 'tableId': t.id, 'guestCount': t.capacity});
        orderId = (created as Map<String, dynamic>)['id'] as String;
      }
      nav.pop(); // close spinner
      await nav.push(MaterialPageRoute(builder: (_) => OrderScreen(orderId: orderId, tableCode: t.code)));
      _refresh();
    } on ApiException catch (e) {
      nav.pop();
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Floor'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              await Api.instance.logout();
              nav.pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<TableModel>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _ErrorView(message: '${snap.error}', onRetry: _refresh);
            }
            final tables = snap.data ?? [];
            if (tables.isEmpty) {
              return const Center(child: Text('No tables yet.'));
            }
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 150,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: tables.length,
              itemBuilder: (context, i) {
                final t = tables[i];
                final (bg, fg) = AppTheme.statusColors(t.status);
                return InkWell(
                  onTap: () => _openTable(t),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: fg.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(t.code, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: fg)),
                        Text('${t.capacity} seats', style: TextStyle(fontSize: 12, color: fg.withValues(alpha: 0.8))),
                        const SizedBox(height: 6),
                        StatusChip(t.status),
                        if (t.area != null) Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(t.area!, style: TextStyle(fontSize: 10, color: fg.withValues(alpha: 0.7))),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 40, color: Colors.black38),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
