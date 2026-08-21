import 'package:flutter/material.dart';

import '../../core/session/session_controller.dart';
import '../../core/widgets/app_widgets.dart';

class TwoFactorScreen extends StatefulWidget {
  const TwoFactorScreen({super.key, required this.session});
  final SessionController session;

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  final _code = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_code.text.trim().length < 6) {
      showMessage(context, 'Enter the 6-digit authenticator code.',
          error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.session.verifyTwoFactor(_code.text);
    } catch (e) {
      if (context.mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (context.mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.phonelink_lock_rounded, size: 46),
                        const SizedBox(height: 14),
                        Text('Two-factor authentication',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        const Text(
                            'Enter the current code from your authenticator app.',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _code,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 8,
                          onSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(
                              labelText: 'Authenticator code', counterText: ''),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                            onPressed: _loading ? null : _submit,
                            child: Text(_loading
                                ? 'Verifying…'
                                : 'Verify and continue')),
                      ]),
                ),
              ),
            ),
          ),
        ),
      );
}
