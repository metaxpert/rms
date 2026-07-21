import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'delivery_detail_screen.dart';

class DeliveriesScreen extends StatefulWidget {
  const DeliveriesScreen({super.key});
  @override
  State<DeliveriesScreen> createState() => _DeliveriesScreenState();
}

class _DeliveriesScreenState extends State<DeliveriesScreen> {
  List<Delivery>? _all;
  Object? _error;
  Timer? _timer;
  bool _showDone = false;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final data = await Api.instance.get('/restaurant/deliveries') as List;
      final list = data.map((e) => Delivery.from(e as Map<String, dynamic>)).toList();
      if (mounted) setState(() { _all = list; _error = null; });
    } on ApiException catch (e) {
      if (e.status == 401 && mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
        return;
      }
      if (mounted && !silent) setState(() => _error = e);
    } catch (e) {
      if (mounted && !silent) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final list = all == null ? <Delivery>[] : all.where((d) => _showDone ? d.isTerminal : d.isActive).toList();
    final activeCount = all?.where((d) => d.isActive).length ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [Text('My runs'), SizedBox(width: 10), LiveDot()]),
        actions: [
          IconButton(onPressed: () => _load(), icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              await Api.instance.logout();
              nav.pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
            icon: const Icon(Icons.logout),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                ChoiceChip(label: Text('Active ($activeCount)'), selected: !_showDone, onSelected: (_) => setState(() => _showDone = false)),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('Completed'), selected: _showDone, onSelected: (_) => setState(() => _showDone = true)),
              ],
            ),
          ),
        ),
      ),
      body: all == null
          ? (_error != null
              ? Center(child: Text('$_error', style: const TextStyle(color: Colors.black54)))
              : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _load,
              child: list.isEmpty
                  ? ListView(children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 120),
                        child: Column(children: [
                          Icon(_showDone ? Icons.history : Icons.local_shipping_outlined, size: 44, color: Colors.black26),
                          const SizedBox(height: 12),
                          Text(_showDone ? 'No completed runs yet.' : 'No active runs. Enjoy the break!', style: const TextStyle(color: Colors.black45)),
                        ]),
                      ),
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final d = list[i];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.statusColors(d.status).$1,
                              child: Icon(d.isOwnFleet ? Icons.pedal_bike : Icons.storefront, color: AppTheme.statusColors(d.status).$2, size: 20),
                            ),
                            title: Text('${d.deliveryNo} · ${d.orderNo}', style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(d.address ?? d.provider, maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                StatusChip(d.status),
                                if (d.etaMinutes != null) Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('ETA ${d.etaMinutes}m', style: const TextStyle(fontSize: 11, color: Colors.black45)),
                                ),
                              ],
                            ),
                            onTap: () async {
                              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeliveryDetailScreen(deliveryId: d.id)));
                              _load();
                            },
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
