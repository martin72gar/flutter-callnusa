import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'CallNusa'**
  String get appName;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your CallNusa account'**
  String get loginSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get signingIn;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address'**
  String get emailRequired;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'That email address is not valid'**
  String get emailInvalid;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordRequired;

  /// No description provided for @tabDialer.
  ///
  /// In en, this message translates to:
  /// **'Dialer'**
  String get tabDialer;

  /// No description provided for @tabHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get tabHistory;

  /// No description provided for @tabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// No description provided for @registrationConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get registrationConnecting;

  /// No description provided for @registrationRegistered.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get registrationRegistered;

  /// No description provided for @registrationRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing…'**
  String get registrationRefreshing;

  /// No description provided for @registrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get registrationFailed;

  /// No description provided for @registrationUnregistered.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get registrationUnregistered;

  /// No description provided for @registrationRetryIn.
  ///
  /// In en, this message translates to:
  /// **'Retrying in {seconds}s'**
  String registrationRetryIn(int seconds);

  /// No description provided for @extensionLabel.
  ///
  /// In en, this message translates to:
  /// **'Extension {extension}'**
  String extensionLabel(String extension);

  /// No description provided for @dialerHint.
  ///
  /// In en, this message translates to:
  /// **'Enter number or extension'**
  String get dialerHint;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @outboundCallingDisabled.
  ///
  /// In en, this message translates to:
  /// **'Outbound calling is disabled for your account'**
  String get outboundCallingDisabled;

  /// No description provided for @incomingCall.
  ///
  /// In en, this message translates to:
  /// **'Incoming call'**
  String get incomingCall;

  /// No description provided for @outgoingCall.
  ///
  /// In en, this message translates to:
  /// **'Calling…'**
  String get outgoingCall;

  /// No description provided for @callRinging.
  ///
  /// In en, this message translates to:
  /// **'Ringing…'**
  String get callRinging;

  /// No description provided for @callConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get callConnected;

  /// No description provided for @callOnHold.
  ///
  /// In en, this message translates to:
  /// **'On hold'**
  String get callOnHold;

  /// No description provided for @callEnding.
  ///
  /// In en, this message translates to:
  /// **'Ending…'**
  String get callEnding;

  /// No description provided for @callEnded.
  ///
  /// In en, this message translates to:
  /// **'Call ended'**
  String get callEnded;

  /// No description provided for @callFailed.
  ///
  /// In en, this message translates to:
  /// **'Call failed'**
  String get callFailed;

  /// No description provided for @unknownCaller.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknownCaller;

  /// No description provided for @mute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mute;

  /// No description provided for @unmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmute;

  /// No description provided for @hold.
  ///
  /// In en, this message translates to:
  /// **'Hold'**
  String get hold;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @speaker.
  ///
  /// In en, this message translates to:
  /// **'Speaker'**
  String get speaker;

  /// No description provided for @keypad.
  ///
  /// In en, this message translates to:
  /// **'Keypad'**
  String get keypad;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @hangUp.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get hangUp;

  /// No description provided for @recordingNotice.
  ///
  /// In en, this message translates to:
  /// **'This call may be recorded'**
  String get recordingNotice;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Call history'**
  String get historyTitle;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get filterMissed;

  /// No description provided for @filterInbound.
  ///
  /// In en, this message translates to:
  /// **'Incoming'**
  String get filterInbound;

  /// No description provided for @filterOutbound.
  ///
  /// In en, this message translates to:
  /// **'Outgoing'**
  String get filterOutbound;

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No calls yet'**
  String get historyEmpty;

  /// No description provided for @missed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get missed;

  /// No description provided for @rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @sectionAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get sectionAudio;

  /// No description provided for @sectionNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get sectionNotifications;

  /// No description provided for @sectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get sectionAbout;

  /// No description provided for @defaultSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Speakerphone by default'**
  String get defaultSpeaker;

  /// No description provided for @autoAnswer.
  ///
  /// In en, this message translates to:
  /// **'Auto-answer incoming calls'**
  String get autoAnswer;

  /// No description provided for @vibrate.
  ///
  /// In en, this message translates to:
  /// **'Vibrate on incoming call'**
  String get vibrate;

  /// No description provided for @ringtone.
  ///
  /// In en, this message translates to:
  /// **'Ringtone'**
  String get ringtone;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @diagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnostics;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get appVersion;

  /// No description provided for @sourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get sourceCode;

  /// No description provided for @license.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get license;

  /// No description provided for @licenseGpl.
  ///
  /// In en, this message translates to:
  /// **'GNU GPL v3.0 only'**
  String get licenseGpl;

  /// No description provided for @openSourceNotices.
  ///
  /// In en, this message translates to:
  /// **'Open-source notices'**
  String get openSourceNotices;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get logout;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Your SIP account will be unregistered and stored credentials removed from this device.'**
  String get logoutConfirmBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your network and try again.'**
  String get errorNetwork;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'The server took too long to respond.'**
  String get errorTimeout;

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Email or password is incorrect.'**
  String get errorInvalidCredentials;

  /// No description provided for @errorSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again.'**
  String get errorSessionExpired;

  /// No description provided for @errorAccountDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled.'**
  String get errorAccountDisabled;

  /// No description provided for @errorNoExtension.
  ///
  /// In en, this message translates to:
  /// **'No extension is assigned to your account. Contact your administrator.'**
  String get errorNoExtension;

  /// No description provided for @errorInvalidConfig.
  ///
  /// In en, this message translates to:
  /// **'Your phone configuration is invalid. Contact your administrator.'**
  String get errorInvalidConfig;

  /// No description provided for @errorDeviceLimit.
  ///
  /// In en, this message translates to:
  /// **'Too many registered devices. Sign out from another device first.'**
  String get errorDeviceLimit;

  /// No description provided for @errorServer.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on our side. Please try again.'**
  String get errorServer;

  /// No description provided for @errorSipRegistration.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to the phone service.'**
  String get errorSipRegistration;

  /// No description provided for @errorCallFailed.
  ///
  /// In en, this message translates to:
  /// **'The call could not be completed.'**
  String get errorCallFailed;

  /// No description provided for @errorBusy.
  ///
  /// In en, this message translates to:
  /// **'The line is busy.'**
  String get errorBusy;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'That number does not exist.'**
  String get errorNotFound;

  /// No description provided for @errorMicPermission.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is required to make calls.'**
  String get errorMicPermission;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorUnknown;

  /// No description provided for @errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a moment and try again.'**
  String get errorRateLimited;

  /// No description provided for @errorPlanLimit.
  ///
  /// In en, this message translates to:
  /// **'Your organisation\'s plan does not allow this device to be provisioned. Contact your administrator.'**
  String get errorPlanLimit;

  /// No description provided for @errorDeviceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This device has been revoked. Sign out and sign in again to register it as a new device.'**
  String get errorDeviceUnavailable;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @forgotPasswordBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we will send you a reset link.'**
  String get forgotPasswordBody;

  /// No description provided for @forgotPasswordSent.
  ///
  /// In en, this message translates to:
  /// **'If the account exists, a reset link has been sent.'**
  String get forgotPasswordSent;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @phoneNotReady.
  ///
  /// In en, this message translates to:
  /// **'Phone service is not ready.'**
  String get phoneNotReady;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
