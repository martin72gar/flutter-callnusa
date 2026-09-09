// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'CallNusa';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get loginSubtitle => 'Sign in with your CallNusa account';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get signIn => 'Sign in';

  @override
  String get signingIn => 'Signing in…';

  @override
  String get emailRequired => 'Enter your email address';

  @override
  String get emailInvalid => 'That email address is not valid';

  @override
  String get passwordRequired => 'Enter your password';

  @override
  String get tabDialer => 'Dialer';

  @override
  String get tabHistory => 'History';

  @override
  String get tabSettings => 'Settings';

  @override
  String get registrationConnecting => 'Connecting…';

  @override
  String get registrationRegistered => 'Ready';

  @override
  String get registrationRefreshing => 'Refreshing…';

  @override
  String get registrationFailed => 'Not connected';

  @override
  String get registrationUnregistered => 'Offline';

  @override
  String registrationRetryIn(int seconds) {
    return 'Retrying in ${seconds}s';
  }

  @override
  String extensionLabel(String extension) {
    return 'Extension $extension';
  }

  @override
  String get dialerHint => 'Enter number or extension';

  @override
  String get call => 'Call';

  @override
  String get outboundCallingDisabled =>
      'Outbound calling is disabled for your account';

  @override
  String get incomingCall => 'Incoming call';

  @override
  String get outgoingCall => 'Calling…';

  @override
  String get callRinging => 'Ringing…';

  @override
  String get callConnected => 'Connected';

  @override
  String get callOnHold => 'On hold';

  @override
  String get callEnding => 'Ending…';

  @override
  String get callEnded => 'Call ended';

  @override
  String get callFailed => 'Call failed';

  @override
  String get unknownCaller => 'Unknown';

  @override
  String get mute => 'Mute';

  @override
  String get unmute => 'Unmute';

  @override
  String get hold => 'Hold';

  @override
  String get resume => 'Resume';

  @override
  String get speaker => 'Speaker';

  @override
  String get keypad => 'Keypad';

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String get hangUp => 'End';

  @override
  String get recordingNotice => 'This call may be recorded';

  @override
  String get historyTitle => 'Call history';

  @override
  String get filterAll => 'All';

  @override
  String get filterMissed => 'Missed';

  @override
  String get filterInbound => 'Incoming';

  @override
  String get filterOutbound => 'Outgoing';

  @override
  String get historyEmpty => 'No calls yet';

  @override
  String get missed => 'Missed';

  @override
  String get rejected => 'Rejected';

  @override
  String get failed => 'Failed';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get sectionAudio => 'Audio';

  @override
  String get sectionNotifications => 'Notifications';

  @override
  String get sectionAbout => 'About';

  @override
  String get defaultSpeaker => 'Speakerphone by default';

  @override
  String get autoAnswer => 'Auto-answer incoming calls';

  @override
  String get vibrate => 'Vibrate on incoming call';

  @override
  String get ringtone => 'Ringtone';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get diagnostics => 'Diagnostics';

  @override
  String get appVersion => 'Version';

  @override
  String get sourceCode => 'Source code';

  @override
  String get license => 'License';

  @override
  String get licenseGpl => 'GNU GPL v3.0 only';

  @override
  String get openSourceNotices => 'Open-source notices';

  @override
  String get logout => 'Sign out';

  @override
  String get logoutConfirmTitle => 'Sign out?';

  @override
  String get logoutConfirmBody =>
      'Your SIP account will be unregistered and stored credentials removed from this device.';

  @override
  String get cancel => 'Cancel';

  @override
  String get retry => 'Retry';

  @override
  String get ok => 'OK';

  @override
  String get errorNetwork => 'No connection. Check your network and try again.';

  @override
  String get errorTimeout => 'The server took too long to respond.';

  @override
  String get errorInvalidCredentials => 'Email or password is incorrect.';

  @override
  String get errorSessionExpired =>
      'Your session has expired. Please sign in again.';

  @override
  String get errorAccountDisabled => 'This account has been disabled.';

  @override
  String get errorNoExtension =>
      'No extension is assigned to your account. Contact your administrator.';

  @override
  String get errorInvalidConfig =>
      'Your phone configuration is invalid. Contact your administrator.';

  @override
  String get errorDeviceLimit =>
      'Too many registered devices. Sign out from another device first.';

  @override
  String get errorServer =>
      'Something went wrong on our side. Please try again.';

  @override
  String get errorSipRegistration => 'Could not connect to the phone service.';

  @override
  String get errorCallFailed => 'The call could not be completed.';

  @override
  String get errorBusy => 'The line is busy.';

  @override
  String get errorNotFound => 'That number does not exist.';

  @override
  String get errorMicPermission =>
      'Microphone access is required to make calls.';

  @override
  String get errorUnknown => 'Something went wrong. Please try again.';

  @override
  String get errorRateLimited =>
      'Too many attempts. Please wait a moment and try again.';

  @override
  String get errorPlanLimit =>
      'Your organisation\'s plan does not allow this device to be provisioned. Contact your administrator.';

  @override
  String get errorDeviceUnavailable =>
      'This device has been revoked. Sign out and sign in again to register it as a new device.';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get forgotPasswordBody =>
      'Enter your email and we will send you a reset link.';

  @override
  String get forgotPasswordSent =>
      'If the account exists, a reset link has been sent.';

  @override
  String get send => 'Send';

  @override
  String get phoneNotReady => 'Phone service is not ready.';
}
