import 'package:flutter/material.dart';

import '../../core/session/session_controller.dart';
import '../../core/widgets/app_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.session});
  final SessionController session;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _company = TextEditingController();
  final _gstin = TextEditingController();
  final _pan = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    for (final c in [
      _name,
      _email,
      _phone,
      _company,
      _gstin,
      _pan,
      _password
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await widget.session.register(
        email: _email.text,
        password: _password.text,
        fullName: _name.text,
        companyName: _company.text,
        phone: _phone.text,
        gstin: _gstin.text,
        pan: _pan.text,
      );
      if (context.mounted)
        Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (context.mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (context.mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create business account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Form(
              key: _formKey,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Owner details',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 14),
                        Wrap(spacing: 14, runSpacing: 14, children: [
                          SizedBox(
                              width: 310,
                              child: TextFormField(
                                  controller: _name,
                                  decoration: const InputDecoration(
                                      labelText: 'Full name'),
                                  validator: _required)),
                          SizedBox(
                              width: 310,
                              child: TextFormField(
                                  controller: _email,
                                  decoration:
                                      const InputDecoration(labelText: 'Email'),
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) => v != null && v.contains('@')
                                      ? null
                                      : 'Enter a valid email')),
                          SizedBox(
                              width: 310,
                              child: TextFormField(
                                  controller: _phone,
                                  decoration: const InputDecoration(
                                      labelText: 'Phone (optional)'),
                                  keyboardType: TextInputType.phone)),
                          SizedBox(
                              width: 310,
                              child: TextFormField(
                                  controller: _password,
                                  obscureText: _obscure,
                                  decoration: InputDecoration(
                                      labelText: 'Password',
                                      helperText:
                                          'Upper/lowercase, digit and special character',
                                      suffixIcon: IconButton(
                                          onPressed: () => setState(
                                              () => _obscure = !_obscure),
                                          icon: Icon(_obscure
                                              ? Icons.visibility_outlined
                                              : Icons
                                                  .visibility_off_outlined))),
                                  validator: (v) => (v?.length ?? 0) < 8
                                      ? 'Use at least 8 characters'
                                      : null)),
                        ]),
                        const SizedBox(height: 24),
                        Text('Business details',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 14),
                        Wrap(spacing: 14, runSpacing: 14, children: [
                          SizedBox(
                              width: 310,
                              child: TextFormField(
                                  controller: _company,
                                  decoration: const InputDecoration(
                                      labelText: 'Legal business name'),
                                  validator: _required)),
                          SizedBox(
                              width: 310,
                              child: TextFormField(
                                  controller: _gstin,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  maxLength: 15,
                                  decoration: const InputDecoration(
                                      labelText: 'GSTIN (optional)',
                                      counterText: ''))),
                          SizedBox(
                              width: 310,
                              child: TextFormField(
                                  controller: _pan,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  maxLength: 10,
                                  decoration: const InputDecoration(
                                      labelText: 'PAN (optional)',
                                      counterText: ''))),
                        ]),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _loading ? null : _submit,
                          icon: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.business_rounded),
                          label: const Text('Create account'),
                        ),
                      ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
}
