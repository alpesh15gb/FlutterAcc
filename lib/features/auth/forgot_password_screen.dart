import 'package:flutter/material.dart';

import '../../core/session/session_controller.dart';
import '../../core/widgets/app_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.session});
  final SessionController session;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_email.text.contains('@')) {
      showMessage(context, 'Enter a valid email address.', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.session.forgotPassword(_email.text);
      if (mounted) {
        showMessage(
            context, 'If the email is registered, a reset link has been sent.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Reset password')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                            'Enter the email used for your ApexBooks account. We will request a password-reset email from the server.'),
                        const SizedBox(height: 18),
                        TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration:
                                const InputDecoration(labelText: 'Email')),
                        const SizedBox(height: 18),
                        FilledButton(
                            onPressed: _loading ? null : _submit,
                            child: Text(
                                _loading ? 'Sending…' : 'Send reset link')),
                      ]),
                ),
              ),
            ),
          ),
        ),
      );
}
