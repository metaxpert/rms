import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import 'login_screen.dart';

/// Bottom-nav shell that owns the shared [Snapshot] and refreshes it every few seconds,
/// so every tab reads live data. Manager is read-only — no mutations here.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _period = Duration(seconds: 8);
  int _tab = 0;
  Snapshot? _snap;
  Object? _error;
  Timer? _timer;
  List<BranchModel> _branches = [];

  @override
  void initState() {
    super.initState();
    _load();
    _loadBranches();
    _timer = Timer.periodic(_period, (_) => _load(silent: true));
  }

  Future<void> _loadBranches() async {
    try {
      final r = await Api.instance.get('/restaurant/branches');
      final list = (r as List).cast<Map<String, dynamic>>().map(BranchModel.from).toList();
      if (mounted) setState(() => _branches = list);
    } catch (_) {
      // Non-fatal — the selector simply offers only "All branches".
    }
  }

  Future<void> _selectBranch(String? id) async {
    await Api.instance.setBranch(id);
    if (mounted) setState(() => _snap = null);
    await _load();
  }

  String get _currentBranchName {
    final id = Api.instance.branchId;
    if (id == null) return 'All branches';
    for (final b in _branches) {
      if (b.id == id) return b.name;
    }
    return 'All branches';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final r = await Future.wait([
        Api.instance.get(Api.instance.branchScoped('/restaurant/orders')),
        Api.instance.get(Api.instance.branchScoped('/restaurant/kds/board')),
        Api.instance.get(Api.instance.branchScoped('/restaurant/tables')),
        Api.instance.get(Api.instance.branchScoped('/restaurant/deliveries')),
        Api.instance.get(Api.instance.branchScoped('/restaurant/reservations')),
      ]);
      List<Map<String, dynamic>> maps(dynamic x) => (x as List).cast<Map<String, dynamic>>();
      final snap = Snapshot(
        orders: maps(r[0]).map(OrderRow.from).toList(),
        tickets: maps(r[1]).map(KdsTicket.from).toList(),
        tables: maps(r[2]),
        deliveries: maps(r[3]),
        reservations: maps(r[4]),
      );
      if (mounted) setState(() { _snap = snap; _error = null; });
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
    final snap = _snap;
    const titles = ['Dashboard', 'Kitchen', 'Sales'];
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(children: [Text(titles[_tab]), const SizedBox(width: 10), const LiveDot()]),
            Text(_currentBranchName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          PopupMenuButton<String?>(
            tooltip: 'Select outlet',
            icon: const Icon(Icons.store_mall_directory_outlined),
            onSelected: (id) => _selectBranch(id == '' ? null : id),
            itemBuilder: (_) {
              final current = Api.instance.branchId;
              return [
                CheckedPopupMenuItem<String?>(
                  value: '',
                  checked: current == null,
                  child: const Text('All branches'),
                ),
                for (final b in _branches)
                  CheckedPopupMenuItem<String?>(
                    value: b.id,
                    checked: current == b.id,
                    child: Text(b.name),
                  ),
              ];
            },
          ),
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
      ),
      body: snap == null
          ? (_error != null
              ? _ErrorView(message: '$_error', onRetry: _load)
              : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _load,
              child: IndexedStack(
                index: _tab,
                children: [DashboardView(snap), KitchenView(snap), SalesView(snap)],
              ),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.restaurant_outlined), selectedIcon: Icon(Icons.restaurant), label: 'Kitchen'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Sales'),
        ],
      ),
    );
  }
}

// ── Dashboard ────────────────────────────────────────────────────────────────
class DashboardView extends StatelessWidget {
  const DashboardView(this.s, {super.key});
  final Snapshot s;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.55,
          children: [
            _Kpi('Open bills', '${s.openBills}', Money.fmt(s.openValueMinor, s.currency), Icons.receipt_long, const Color(0xFF1B7A4B)),
            _Kpi('Covers seated', '${s.occupiedTables}/${s.totalTables}', 'tables occupied', Icons.groups, const Color(0xFF1F6390)),
            _Kpi('Kitchen tickets', '${s.liveTickets}', 'in progress', Icons.restaurant, const Color(0xFF8A5A20)),
            _Kpi('Deliveries out', '${s.activeDeliveries}', 'active jobs', Icons.pedal_bike, const Color(0xFF1F6390)),
            _Kpi('Bookings', '${s.upcomingReservations}', 'upcoming', Icons.event, const Color(0xFFA02840)),
            _Kpi('Settled today', '${s.settledCount}', Money.fmt(s.settledValueMinor, s.currency), Icons.payments, AppTheme.primary),
          ],
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text('Open orders', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ),
        if (s.openOrders.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('Nothing open — all settled.', style: TextStyle(color: Colors.black54)))
        else
          ...s.openOrders.map((o) => Card(
                child: ListTile(
                  title: Text(o.orderNo, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${o.channel.replaceAll('_', ' ').toLowerCase()}${o.table != null ? ' · ${o.table}' : ''} · ${o.itemCount} items'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [Text(o.total.formatted, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 4), StatusChip(o.status)],
                  ),
                ),
              )),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.sub, this.icon, this.tint);
  final String label, value, sub;
  final IconData icon;
  final Color tint;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
              Icon(icon, size: 18, color: tint),
            ]),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text(sub, style: const TextStyle(color: Colors.black45, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ── Kitchen (KDS) ────────────────────────────────────────────────────────────
class KitchenView extends StatelessWidget {
  const KitchenView(this.s, {super.key});
  final Snapshot s;

  String _mmss(int sec) {
    final s = sec < 0 ? 0 : sec;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (s.tickets.isEmpty) {
      return const Center(child: Text('No tickets fired. The board is clear.', style: TextStyle(color: Colors.black54)));
    }
    final byStation = <String, List<KdsTicket>>{};
    for (final t in s.tickets) {
      byStation.putIfAbsent(t.station, () => []).add(t);
    }
    final stations = byStation.keys.toList()..sort();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final st in stations) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
            child: Row(children: [
              Text(st.replaceAll('_', ' '), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFEDE7DE), borderRadius: BorderRadius.circular(999)),
                child: Text('${byStation[st]!.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          for (final t in byStation[st]!)
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: t.overdue ? const Color(0xFFE79AA8) : const Color(0xFFEBE3D8)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${t.orderNo}${t.table != null ? ' · ${t.table}' : ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        Row(children: [
                          Icon(Icons.timer_outlined, size: 14, color: t.overdue ? const Color(0xFFA02840) : Colors.black45),
                          const SizedBox(width: 3),
                          Text(_mmss(t.elapsedSeconds), style: TextStyle(color: t.overdue ? const Color(0xFFA02840) : Colors.black54, fontWeight: t.overdue ? FontWeight.w700 : FontWeight.w500, fontSize: 12)),
                        ]),
                      ],
                    ),
                    const SizedBox(height: 6),
                    StatusChip(t.status),
                    const SizedBox(height: 6),
                    ...t.items.map((i) => Text('${i.qty}×  ${i.name}', style: const TextStyle(fontSize: 13))),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

// ── Sales ────────────────────────────────────────────────────────────────────
class SalesView extends StatelessWidget {
  const SalesView(this.s, {super.key});
  final Snapshot s;

  @override
  Widget build(BuildContext context) {
    final settled = s.orders.where((o) => o.isSettled).toList();
    final avg = settled.isEmpty ? 0 : s.settledValueMinor ~/ settled.length;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          color: AppTheme.primary,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Settled revenue', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text(Money.fmt(s.settledValueMinor, s.currency), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('${settled.length} bills · avg ${Money.fmt(avg, s.currency)} · ${Money.fmt(s.openValueMinor, s.currency)} still open',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Padding(padding: EdgeInsets.fromLTRB(4, 8, 4, 8), child: Text('Settled bills', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
        if (settled.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('No settled bills yet.', style: TextStyle(color: Colors.black54)))
        else
          ...settled.map((o) => Card(
                child: ListTile(
                  leading: const Icon(Icons.check_circle, color: Color(0xFF1B7A4B)),
                  title: Text(o.orderNo, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${o.channel.replaceAll('_', ' ').toLowerCase()}${o.table != null ? ' · ${o.table}' : ''}'),
                  trailing: Text(o.total.formatted, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              )),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;
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
            FilledButton(onPressed: () => onRetry(), child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
