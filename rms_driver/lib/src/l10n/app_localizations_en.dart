// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppTextEn extends AppText {
  AppTextEn([String locale = 'en']) : super(locale);

  @override
  String get runsTitle => 'Runs';

  @override
  String get switchOutlet => 'Switch outlet';

  @override
  String get signOut => 'Sign out';

  @override
  String get runsLoading => 'Loading your runs…';

  @override
  String get nothingToDeliverTitle => 'Nothing to deliver';

  @override
  String get nothingToDeliverMessage =>
      'New runs appear here as the kitchen dispatches them. Pull down to check again.';

  @override
  String get sectionOnTheGo => 'On the go';

  @override
  String get sectionDoneToday => 'Done today';

  @override
  String get noAddress => 'No address on file';

  @override
  String etaMinutes(int minutes) {
    return 'ETA $minutes min';
  }

  @override
  String assignedAt(String time) {
    return 'assigned $time';
  }

  @override
  String notYours(String provider) {
    return '$provider — not yours to drive';
  }

  @override
  String get run => 'Run';

  @override
  String get dropOff => 'Drop-off';

  @override
  String get noAddressCall => 'No address on file — call the restaurant.';

  @override
  String get copy => 'Copy';

  @override
  String get coordinatesCopied => 'Coordinates copied — paste into Maps.';

  @override
  String get sharingLocation => 'Sharing your location';

  @override
  String get locationOff => 'Location off';

  @override
  String get sharingOnHint =>
      'The customer can see roughly where you are. It stops when the run finishes.';

  @override
  String get sharingOffHint =>
      'Turn on while you are carrying this order so the customer can follow it.';

  @override
  String lastSent(String time, int count) {
    return 'Last sent $time · $count updates';
  }

  @override
  String get locationServiceOff =>
      'Location is switched off on this phone. Turn it on in the pull-down settings, then try again.';

  @override
  String get locationDenied =>
      'The app was not given permission this time. Tap the switch again to be asked once more.';

  @override
  String get locationBlocked =>
      'Location permission is blocked for this app. It can only be turned back on in the phone\'s Settings → Apps.';

  @override
  String get locationForegroundOnly =>
      'Tracking only works while this screen is open. To keep the customer\'s map moving with the phone in your pocket, allow location \"all the time\" in Settings.';

  @override
  String get progress => 'Progress';

  @override
  String get progressAssigned => 'Assigned';

  @override
  String get progressPickedUp => 'Picked up';

  @override
  String get progressDelivered => 'Delivered';

  @override
  String runIsStatus(String status) {
    return 'This run is $status.';
  }

  @override
  String aggregatorCarrying(String provider) {
    return '$provider is carrying this one. Track it through their app — nothing here changes it.';
  }

  @override
  String get waitingForAssignment =>
      'Waiting for the restaurant to assign this run.';

  @override
  String get somethingWentWrong => 'Something went wrong';

  @override
  String get confirmHandover => 'Confirm the handover';

  @override
  String get askForCode =>
      'Ask the customer to read out the code on their order.';

  @override
  String get deliveryCode => 'Delivery code';

  @override
  String get cancel => 'Cancel';

  @override
  String get delivered => 'Delivered';

  @override
  String get failNobodyThere => 'Nobody at the address';

  @override
  String get failRefused => 'Customer refused the order';

  @override
  String get failAddressNotFound => 'Address could not be found';

  @override
  String get failNoCode => 'Customer would not give the code';

  @override
  String get failVehicle => 'Accident or vehicle problem';

  @override
  String get whatHappened => 'What happened?';

  @override
  String get markFailedTitle => 'Mark this run failed?';

  @override
  String markFailedMessage(String reason) {
    return '\"$reason\"\n\nThe restaurant is told straight away. This cannot be undone from here.';
  }

  @override
  String get goBack => 'Go back';

  @override
  String get markFailed => 'Mark failed';

  @override
  String get driverSignIn => 'Driver sign in';

  @override
  String get whichKitchen => 'Which kitchen?';

  @override
  String get runAssigned => 'A run has been assigned.';

  @override
  String get startShift => 'Start shift';

  @override
  String get endShift => 'End shift';

  @override
  String get offShift => 'Off shift — you will not be given deliveries';

  @override
  String onShiftSummary(int live, int done) {
    return 'On shift · $live in hand · $done delivered today';
  }

  @override
  String get riderNotLinked =>
      'This login is not linked to a rider yet. Ask your manager to link it on the rider roster.';

  @override
  String get riderProfileUnavailable => 'Could not load your rider details.';

  @override
  String get yourRunsOnly =>
      'These are your runs only. A job you cannot see has been given to another rider.';
}
