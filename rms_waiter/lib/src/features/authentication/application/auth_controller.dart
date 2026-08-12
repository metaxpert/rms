import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rms_core/rms_core.dart';
import '../data/auth_repository.dart';

/// Where the user is in the sign-in journey.
///
/// `needsBranch` is a distinct state rather than a flag because a waiter who is
/// authenticated but has not chosen an outlet must not reach the floor — every
/// branch-scoped read would silently return another outlet's tables.
enum AuthStatus { signedOut, needsBranch, ready }

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

    return AuthState(status: _statusFor(session));
  }

  static AuthStatus _statusFor(Session session) {
    if (!session.isAuthenticated) return AuthStatus.signedOut;
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
      state = const AuthState(status: AuthStatus.needsBranch);
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

  /// Return to outlet selection without signing out — used when a waiter moves
  /// between outlets mid-shift.
  Future<void> clearBranch() async {
    await ref.read(sessionProvider).setBranchId(null);
    state = state.copyWith(status: AuthStatus.needsBranch);
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
