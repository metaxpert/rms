import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api.dart';
import '../theme.dart';

/// The bill as it will come off the thermal printer.
///
/// The server renders the slip (same document the printer gets), so what the waiter shows a guest on
/// the phone is byte-for-byte what the paper says — no second layout to drift out of sync. "Send to
/// printer" only queues the job; the till's print agent pushes it, so a jammed printer never blocks
/// the waiter.
class ReceiptSheet extends StatefulWidget {
  const ReceiptSheet({super.key, required this.orderId, required this.orderNo, required this.settled});
  final String orderId;
  final String orderNo;
  final bool settled;

  static Future<void> show(BuildContext context, {required String orderId, required String orderNo, required bool settled}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReceiptSheet(orderId: orderId, orderNo: orderNo, settled: settled),
    );
  }

  @override
  State<ReceiptSheet> createState() => _ReceiptSheetState();
}

class _ReceiptSheetState extends State<ReceiptSheet> {
  String? _text;
  String? _error;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // 32 columns renders the narrow 58mm layout, which is what fits a phone screen legibly.
      final res = await Api.instance.get('/restaurant/orders/${widget.orderId}/receipt?charsPerLine=32');
      if (mounted) setState(() => _text = (res as Map<String, dynamic>)['text'] as String?);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _send({bool reprint = false}) async {
    setState(() => _sending = true);
    try {
      await Api.instance.post('/restaurant/orders/${widget.orderId}/print', {'reprint': reprint});
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(reprint ? 'Reprint queued' : 'Bill sent to the printer')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.settled ? 'Receipt · ${widget.orderNo}' : 'Pro-forma · ${widget.orderNo}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (_text != null)
                    IconButton(
                      tooltip: 'Copy',
                      icon: const Icon(Icons.copy_all_outlined),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _text!));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
                      },
                    ),
                ],
              ),
            ),
            if (!widget.settled)
              Container(
                width: double.infinity,
                color: const Color(0xFFFBEBC8),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: const Text('Not settled — prints as a pro-forma, not a tax invoice.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF8A5A20))),
              ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: _error != null
                  ? Padding(padding: const EdgeInsets.all(24), child: Text(_error!))
                  : _text == null
                      ? const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.black26 : const Color(0xFFF6F6F4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(_text!, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.25)),
                          ),
                        ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _sending ? null : () => _send(reprint: true),
                      icon: const Icon(Icons.replay),
                      label: const Text('Reprint'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                      onPressed: _sending ? null : () => _send(),
                      icon: const Icon(Icons.print_outlined),
                      label: Text(_sending ? 'Sending…' : 'Print bill'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
