import 'package:meta/meta.dart';

@immutable
class AppSettings {
  const AppSettings({
    this.defaultSpeaker = false,
    this.autoAnswer = false,
    this.vibrate = true,
    this.ringtone = 'default',
    this.languageCode,
  });

  final bool defaultSpeaker;
  final bool autoAnswer;
  final bool vibrate;
  final String ringtone;

  /// `null` follows the system locale.
  final String? languageCode;

  AppSettings copyWith({
    bool? defaultSpeaker,
    bool? autoAnswer,
    bool? vibrate,
    String? ringtone,
    String? languageCode,
    bool clearLanguage = false,
  }) => AppSettings(
    defaultSpeaker: defaultSpeaker ?? this.defaultSpeaker,
    autoAnswer: autoAnswer ?? this.autoAnswer,
    vibrate: vibrate ?? this.vibrate,
    ringtone: ringtone ?? this.ringtone,
    languageCode: clearLanguage ? null : languageCode ?? this.languageCode,
  );

  factory AppSettings.fromJson(Map<dynamic, dynamic> json) => AppSettings(
    defaultSpeaker: json['default_speaker'] as bool? ?? false,
    autoAnswer: json['auto_answer'] as bool? ?? false,
    vibrate: json['vibrate'] as bool? ?? true,
    ringtone: json['ringtone'] as String? ?? 'default',
    languageCode: json['language_code'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'default_speaker': defaultSpeaker,
    'auto_answer': autoAnswer,
    'vibrate': vibrate,
    'ringtone': ringtone,
    'language_code': languageCode,
  };
}
