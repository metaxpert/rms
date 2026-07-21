import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';

class DeliveryDetailScreen extends StatefulWidget {
  const DeliveryDetailScreen({super.key, required this.deliveryId});
  final String deliveryId;

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  Delivery? _d;
  Object? _error;
  bool _busy = false;
  int _pings = 0;
  // Simulated route around F-7 Markaz, Islamabad (real device would use the GPS plugin).
  static const _baseLat = 33.7167, _baseLng = 73.0417;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final j = await Api.instance.get('/restaurant/deliveries/${widget.deliveryId}');
      if (mounted) setState(() { _d = Delivery.from(j as Map<String, dynamic>); _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _run(Future<void> Function() action, String ok) async {
    setState(() => _busy = true);
    try {
      await action();
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok), duration: const Duration(milliseconds: 1000)));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickup() => _run(() => Api.instance.post('/restaurant/deliveries/${widget.deliveryId}/pickup'), 'Picked up');
  Future<void> _enroute() => _run(() => Api.instance.post('/restaurant/deliveries/${widget.deliveryId}/enroute'), 'On the way');
  Future<void> _fail() => _run(() => Api.instance.post('/restaurant/deliveries/${widget.deliveryId}/fail', {'reason': 'Reported from driver app'}), 'Marked failed');

  Future<void> _share() {
    _pings++;
    final lat = _baseLat + _pings * 0.0007;
    final lng = _baseLng + _pings * 0.0005;
    return _run(
      () => Api.instance.post('/restaurant/deliveries/${widget.deliveryId}/track', {'geoLat': lat, 'geoLng': lng, 'speedKph': 24 + _pings % 8}),
      'Location shared',
    );
  }

  Future<void> _complete() async {
    final otp = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Confirm delivery'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ask the customer for the OTP on their order.'),
              const SizedBox(height: 12),
              TextField(
                controller: c,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Delivery OTP'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Deliver')),
          ],
        );
      },
    );
    if (otp == null || otp.isEmpty) return;
    await _run(() => Api.instance.post('/restaurant/deliveries/${widget.deliveryId}/complete', {'otp': otp}), 'Delivered 🎉');
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Scaffold(
      appBar: AppBar(title: Text(d?.deliveryNo ?? 'Delivery')),
      body: d == null
          ? (_error != null ? Center(child: Text('$_error')) : const Center(child: CircularProgressIndicator()))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [Expanded(child: Text(d.orderNo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))), StatusChip(d.status)]),
                const SizedBox(height: 4),
                Text('${d.provider} · ${d.etaMinutes != null ? 'ETA ${d.etaMinutes} min' : 'no ETA'}', style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 16),
                _MapCard(lat: d.lat, lng: d.lng, pings: _pings),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.location_on_outlined, color: AppTheme.primary),
                    title: const Text('Drop-off'),
                    subtitle: Text(d.address ?? 'No address on file'),
                  ),
                ),
                const SizedBox(height: 16),
                if (d.isOwnFleet && !d.isTerminal) _actions(d) else if (d.isTerminal) _terminalBanner(d),
              ],
            ),
    );
  }

  Widget _terminalBanner(Delivery d) {
    final (bg, fg) = AppTheme.statusColors(d.status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(d.status == 'DELIVERED' ? Icons.check_circle : Icons.cancel, color: fg),
        const SizedBox(width: 10),
        Text('Run ${d.status.toLowerCase()}', style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 16)),
      ]),
    );
  }

  Widget _actions(Delivery d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (d.status == 'ASSIGNED')
          FilledButton.icon(onPressed: _busy ? null : _pickup, icon: const Icon(Icons.shopping_bag_outlined), label: const Text('Picked up the order')),
        if (d.status == 'PICKED_UP')
          FilledButton.icon(onPressed: _busy ? null : _enroute, icon: const Icon(Icons.navigation_outlined), label: const Text('Start the drive')),
        if (d.canTrack) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: _busy ? null : _share, icon: const Icon(Icons.my_location), label: Text(_pings == 0 ? 'Share my location' : 'Update location ($_pings sent)')),
        ],
        if (d.canComplete) ...[
          const SizedBox(height: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B7A4B)),
            onPressed: _busy ? null : _complete,
            icon: const Icon(Icons.check),
            label: const Text('Deliver — enter OTP'),
          ),
        ],
        const SizedBox(height: 10),
        TextButton.icon(onPressed: _busy ? null : _fail, icon: const Icon(Icons.report_gmailerrorred, color: Color(0xFFA02840)), label: const Text('Report a problem', style: TextStyle(color: Color(0xFFA02840)))),
      ],
    );
  }
}

/// A lightweight "map" — a schematic tile with the last shared location. A production build swaps in
/// a real map SDK (Google/Mapbox); kept dependency-free here.
class _MapCard extends StatelessWidget {
  const _MapCard({required this.lat, required this.lng, required this.pings});
  final double? lat, lng;
  final int pings;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEBE3D8)),
        gradient: const LinearGradient(colors: [Color(0xFFEFF3EA), Color(0xFFE6EEF3)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Stack(
        children: [
          // faux streets
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on, color: pings > 0 ? AppTheme.primary : Colors.black26, size: 34),
                Text(
                  lat != null ? '${lat!.toStringAsFixed(4)}, ${lng!.toStringAsFixed(4)}' : 'Location not shared yet',
                  style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600),
                ),
                if (pings > 0) Text('$pings pings sent', style: const TextStyle(fontSize: 11, color: Colors.black38)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 26) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 26) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
