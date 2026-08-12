import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/api_exception.dart';
import '../providers.dart';
import 'auth_repository.dart';
import 'session.dart';

/// Where the user is in the sign-in journey.
///
/// `needsBranch` is a distinct state rather than a flag because a waiter who is
/// authenticated but has not chosen an outlet must not reach the floor — every
/// branch-scoped read would silently return another outlet's tables.
enum AuthStatus { signedOut, needsBranch, ready }

/// Whether this app can work at all without an outlet chosen.
///
/// True for the apps that DO one outlet's work: a waiter's floor, a rider's
/// board and a customer's menu are all meaningless tenant-wide, and letting
/// them through would silently show another outlet's data. A manager is the
/// exception — comparing outlets is the job — so the manager app overrides this
/// to false and treats the outlet as a filter rather than a gate.
final authRequiresBranchProvider = Provider<bool>((ref) => true);

class AuthState {
  const AuthState({
    required this.status,
    this.isBusy = false,
    this.error,
  });

  final AuthStatus status;
  final bool isBusy;

  /// Last failure, for the sign-in form to render. Cleared on the next attempt.
  final ApiException? error;

  bool get isAuthenticated => status != AuthStatus.signedOut;

  AuthState copyWith({
    AuthStatus? status,
    bool? isBusy,
    ApiException? error,
    bool clearError = false,
  }) =>
      AuthState(
        status: status ?? this.status,
        isBusy: isBusy ?? this.isBusy,
        error: clearError ? null : (error ?? this.error),
      );
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final session = ref.watch(sessionProvider);

    // The API client cannot import UI, so it reports an unrecoverable auth
    // failure through this callback — e.g. the refresh token was revoked
    // server-side while the tablet slept.
    ref.watch(apiClientProvider).onAuthenticationLost = _onAuthenticationLost;

    _requiresBranch = ref.watch(authRequiresBranchProvider);
    return AuthState(status: _statusFor(session));
  }

  var _requiresBranch = true;

  AuthStatus _statusFor(Session session) {
    if (!session.isAuthenticated) return AuthStatus.signedOut;
    if (!_requiresBranch) return AuthStatus.ready;
    return session.branchId == null ? AuthStatus.needsBranch : AuthStatus.ready;
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    if (state.isBusy) return; // double-tap guard on a slow connection
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await ref.read(authRepositoryProvider).signIn(
            email: email,
            password: password,
          );
      state = AuthState(
        status: _requiresBranch ? AuthStatus.needsBranch : AuthStatus.ready,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isBusy: false, error: e);
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isBusy: true, clearError: true);
    await ref.read(authRepositoryProvider).signOut();
    state = const AuthState(status: AuthStatus.signedOut);
  }

  /// Record the chosen outlet; every branch-scoped request reads it from the
  /// session afterwards.
  Future<void> selectBranch(String branchId) async {
    await ref.read(sessionProvider).setBranchId(branchId);
    state = state.copyWith(status: AuthStatus.ready, clearError: true);
  }

  /// Drop the chosen outlet — a waiter moving between outlets mid-shift, or a
  /// manager widening the view back to every outlet.
  ///
  /// Which of those it means is [authRequiresBranchProvider]'s call: for the
  /// single-outlet apps this returns to the picker, for a manager it simply
  /// removes the filter.
  Future<void> clearBranch() async {
    await ref.read(sessionProvider).setBranchId(null);
    state = state.copyWith(
      status: _requiresBranch ? AuthStatus.needsBranch : AuthStatus.ready,
    );
  }

  void _onAuthenticationLost() {
    // The session is already cleared by ApiClient; reflect it so the router
    // redirects to sign-in on the next frame.
    if (state.status != AuthStatus.signedOut) {
      state = const AuthState(status: AuthStatus.signedOut);
    }
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
