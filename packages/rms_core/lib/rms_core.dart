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

// Localisation. Shared because the sign-in journey and every error surface are
// word-for-word identical in all four apps; translating them four times is how
// four translations drift.
export 'src/l10n/rms_localizations.dart';
export 'src/l10n/strings.dart';
export 'src/l10n/locale_binding.dart';

// Money — integer minor units; never floats (see ARCHITECTURE.md §6).
export 'src/money.dart';

// Errors
export 'src/errors/api_exception.dart';

// Networking, session and storage
export 'src/net/api_client.dart';
export 'src/auth/session.dart';
export 'src/storage/secret_store.dart';
export 'src/storage/response_cache.dart';
export 'src/auth/permissions.dart';

// The sign-in journey, shared by all four apps. Identical everywhere except
// the wording — writing it out per app is how four copies of the same missing
// token refresh got shipped.
export 'src/auth/auth_controller.dart';
export 'src/auth/auth_repository.dart';
export 'src/auth/sign_in_screen.dart';
export 'src/auth/server_settings_sheet.dart';
export 'src/branches/branch_repository.dart';
export 'src/branches/branch_selection_screen.dart';

// Realtime — an accelerator over the REST contract, never a replacement for it.
export 'src/realtime/realtime_client.dart';
export 'src/realtime/realtime_event.dart';

// Dependency graph
export 'src/providers.dart';

// The catalogue. Shared because a waiter's picker and a customer's menu read
// exactly the same three endpoints; only the presentation differs.
export 'src/menu/menu_repository.dart';

// Design system and shared state surfaces. One system across four apps: the
// tokens and components are identical everywhere, and only AppFlavor's primary
// hue tells the apps apart.
export 'src/theme/app_theme.dart';
export 'src/widgets/state_views.dart';
export 'src/widgets/app_components.dart';
export 'src/widgets/skeletons.dart';

// Domain vocabulary, mirroring the backend exactly
export 'src/domain/branch.dart';
export 'src/domain/delivery.dart';
export 'src/domain/kds_ticket.dart';
export 'src/domain/menu.dart';
export 'src/domain/order_detail.dart';
export 'src/domain/order_status.dart';
export 'src/domain/order_summary.dart';
export 'src/domain/payment.dart';
export 'src/domain/restaurant_config.dart';
export 'src/domain/restaurant_table.dart';
export 'src/domain/table_status.dart';
export 'src/domain/ticket_draft.dart';
