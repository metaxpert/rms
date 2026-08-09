import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import 'menu_screen.dart';

/// Restaurant picker shown after login (and reachable from the menu app bar). Choosing an outlet
/// scopes every subsequent read/write to that branch, so prices and delivery reflect the chosen
/// restaurant. A customer must pick one before ordering.
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
    nav.pushReplacement(MaterialPageRoute(builder: (_) => const MenuScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a restaurant')),
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
            return const Center(child: Text('No restaurants available yet.\nPlease check back soon.', textAlign: TextAlign.center));
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
                  subtitle: Text([if (b.code != null) b.code!, if (b.isHeadOffice) 'Flagship'].join(' · ')),
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
