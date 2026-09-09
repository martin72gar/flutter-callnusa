import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../config/constants.dart';
import '../../core/auth/auth_state.dart';
import '../../shared/utils/error_messages.dart';
import '../../shared/utils/extensions.dart';
import '../../shared/utils/validators.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/error_message.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    // The password controller holds the plaintext only for the lifetime of the
    // form; clear it explicitly rather than waiting for the GC.
    _password.clear();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(authServiceProvider)
        .login(email: _email.text.trim(), password: _password.text);
    _password.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auth = ref.watch(authStateProvider).value ?? const AuthState();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.phone_in_talk,
                        size: 56,
                        color: context.colors.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AppConstants.appName,
                        textAlign: TextAlign.center,
                        style: context.texts.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.loginSubtitle,
                        textAlign: TextAlign.center,
                        style: context.texts.bodyMedium,
                      ),
                      const SizedBox(height: 32),
                      if (auth.error != null) ...[
                        ErrorMessage(message: messageFor(l10n, auth.error)),
                        const SizedBox(height: 16),
                      ],
                      AppTextField(
                        controller: _email,
                        label: l10n.emailLabel,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username],
                        textInputAction: TextInputAction.next,
                        enabled: !auth.isBusy,
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) return l10n.emailRequired;
                          if (!Validators.isEmail(value)) {
                            return l10n.emailInvalid;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _password,
                        label: l10n.passwordLabel,
                        obscure: true,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        enabled: !auth.isBusy,
                        onSubmitted: _submit,
                        validator: (v) =>
                            (v ?? '').isEmpty ? l10n.passwordRequired : null,
                      ),
                      const SizedBox(height: 24),
                      AppButton(
                        label: auth.isBusy ? l10n.signingIn : l10n.signIn,
                        busy: auth.isBusy,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
