import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import 'tables_screen.dart';

/// Outlet picker shown after login (and reachable from the floor app bar). Choosing a branch
/// scopes every subsequent read/write to that outlet. An unconfigured branch can still be picked —
/// the first order auto-provisions its config from head office on the server.
class BranchScreen extends StatefulWidget {
  const BranchScreen({super.key});

  @override
  State<BranchScreen> createState() => _BranchScreenState();
}

class _BranchScreenState extends State<BranchScreen> {
  late Future<List<BranchModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<BranchModel>> _load() async {
    final data = await Api.instance.get('/restaurant/branches') as List;
    return data.map((e) => BranchModel.from(e as Map<String, dynamic>)).toList();
  }

  Future<void> _choose(BranchModel b) async {
    final nav = Navigator.of(context);
    await Api.instance.setBranch(b.id);
    nav.pushReplacement(MaterialPageRoute(builder: (_) => const TablesScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your outlet')),
      body: FutureBuilder<List<BranchModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${snap.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: () => setState(() => _future = _load()), child: const Text('Retry')),
                  ],
                ),
              ),
            );
          }
          final branches = snap.data ?? [];
          if (branches.isEmpty) {
            return const Center(child: Text('No branches set up yet.\nAsk an admin to add an outlet.', textAlign: TextAlign.center));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: branches.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final b = branches[i];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFFF3E2D2), foregroundColor: AppTheme.primary, child: Icon(Icons.storefront)),
                  title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text([if (b.code != null) b.code!, if (b.isHeadOffice) 'Head office', b.configured ? 'Ready' : 'Setup on first order'].join(' · ')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _choose(b),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
