/// Shared foundation for the four MetaXperts RMS apps.
///
/// Extracted because all four shipped an identical 125-line API client with
/// **no token refresh** — so every app signed staff out after 15 minutes of
/// service. Fixing that in one place beats fixing it four times and letting the
/// copies drift.
///
/// What belongs here: anything that talks to the ERP the same way regardless of
/// who is holding the device — money arithmetic that must reconcile against the
/// GL, the API contract, session handling, and the domain vocabulary the
/// backend defines.
///
/// What does NOT belong here: screens, navigation, and role-specific workflow.
/// A waiter's floor plan and a driver's run list share a client, not a UI.
library;

// Configuration
export 'src/config/environment.dart';

// Money — integer minor units; never floats (see ARCHITECTURE.md §6).
export 'src/money.dart';

// Errors
export 'src/errors/api_exception.dart';

// Networking, session and storage
export 'src/net/api_client.dart';
export 'src/auth/session.dart';
export 'src/storage/secret_store.dart';

// Dependency graph
export 'src/providers.dart';

// Design system and shared state surfaces
export 'src/theme/app_theme.dart';
export 'src/widgets/state_views.dart';

// Domain vocabulary, mirroring the backend exactly
export 'src/domain/branch.dart';
export 'src/domain/order_status.dart';
export 'src/domain/order_summary.dart';
export 'src/domain/restaurant_table.dart';
export 'src/domain/table_status.dart';
