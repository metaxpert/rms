import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/providers.dart';
import '../domain/branch.dart';

class BranchRepository {
  BranchRepository(this._client);

  final ApiClient _client;

  Future<List<Branch>> list() async {
    final data = await _client.get('/restaurant/branches');
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Branch.fromJson)
        .toList(growable: false);
  }
}

final branchRepositoryProvider = Provider<BranchRepository>(
  (ref) => BranchRepository(ref.watch(apiClientProvider)),
);

/// Outlets available to the signed-in user.
///
/// `autoDispose` so switching outlets refetches rather than showing a list
/// cached from a previous session — a manager may have added or deactivated an
/// outlet since sign-in.
final branchesProvider = FutureProvider.autoDispose<List<Branch>>(
  (ref) => ref.watch(branchRepositoryProvider).list(),
);
