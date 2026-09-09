import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The number currently typed on the dial pad.
class DialerViewModel extends Notifier<String> {
  @override
  String build() => '';

  /// Dial pad keys only; anything else is ignored so a paste cannot inject
  /// characters the SIP stack would reject.
  static const _allowed = '0123456789*#+';

  void press(String key) {
    if (!_allowed.contains(key) || state.length >= 32) return;
    state = state + key;
  }

  void backspace() {
    if (state.isEmpty) return;
    state = state.substring(0, state.length - 1);
  }

  void clear() => state = '';

  void set(String value) =>
      state = value.split('').where(_allowed.contains).join();
}

final dialerProvider = NotifierProvider<DialerViewModel, String>(
  DialerViewModel.new,
);
