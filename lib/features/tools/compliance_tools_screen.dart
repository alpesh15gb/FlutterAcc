import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';

class ComplianceToolsScreen extends StatefulWidget {
  const ComplianceToolsScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<ComplianceToolsScreen> createState() => _ComplianceToolsScreenState();
}

class _ComplianceToolsScreenState extends State<ComplianceToolsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<Map<String, dynamic>> _reminders = [];
  bool _loadingReminders = true;
  String? _reminderError;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadReminders();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadReminders() async {
    if (mounted)
      setState(() {
        _loadingReminders = true;
        _reminderError = null;
      });
    try {
      final data = await widget.api.get('/reminders');
      if (mounted) {
        setState(() => _reminders = (data as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList());
      }
    } catch (e) {
      if (mounted) setState(() => _reminderError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingReminders = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
        title: 'Compliance Tools',
        subtitle:
            'Live business reminders, GSTIN verification and HSN/SAC reference lookup.',
        child: Column(children: [
          SectionCard(
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabs: const [
                Tab(
                    icon: Icon(Icons.notifications_active_outlined),
                    text: 'Reminders'),
                Tab(
                    icon: Icon(Icons.verified_user_outlined),
                    text: 'GSTIN Verify'),
                Tab(icon: Icon(Icons.search_rounded), text: 'HSN / SAC'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: _tabs,
            builder: (context, _) => switch (_tabs.index) {
              0 => _remindersTab(),
              1 => _GstinVerifyCard(api: widget.api),
              _ => _HsnLookupCard(api: widget.api),
            },
          ),
        ]),
      );

  Widget _remindersTab() {
    if (_loadingReminders)
      return const Padding(
          padding: EdgeInsets.all(50), child: CircularProgressIndicator());
    if (_reminderError != null)
      return ErrorPanel(message: _reminderError!, onRetry: _loadReminders);
    return SectionCard(
      title: 'Business reminders',
      trailing: IconButton(
          onPressed: _loadReminders,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh'),
      child: _reminders.isEmpty
          ? const Text('No reminders are due right now.',
              style: TextStyle(color: AppColors.muted))
          : Column(children: [
              for (final reminder in _reminders)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                      child: Icon(Icons.notifications_none_rounded)),
                  title: Text(reminder['title']?.toString() ?? 'Reminder',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(reminder['message']?.toString() ?? ''),
                ),
            ]),
    );
  }
}

class _GstinVerifyCard extends StatefulWidget {
  const _GstinVerifyCard({required this.api});
  final ApiClient api;

  @override
  State<_GstinVerifyCard> createState() => _GstinVerifyCardState();
}

class _GstinVerifyCardState extends State<_GstinVerifyCard> {
  final _gstin = TextEditingController();
  final _captcha = TextEditingController();
  String? _sessionId;
  Uint8List? _captchaImage;
  Map<String, dynamic>? _result;
  bool _loadingCaptcha = false;
  bool _verifying = false;

  @override
  void dispose() {
    _gstin.dispose();
    _captcha.dispose();
    super.dispose();
  }

  Future<void> _loadCaptcha() async {
    setState(() {
      _loadingCaptcha = true;
      _result = null;
    });
    try {
      final data = Map<String, dynamic>.from(
          await widget.api.get('/gst/verify/captcha') as Map);
      final encoded = data['image']?.toString() ?? '';
      final clean = encoded.contains(',') ? encoded.split(',').last : encoded;
      setState(() {
        _sessionId = data['session_id']?.toString();
        _captchaImage = base64Decode(clean);
        _captcha.clear();
      });
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loadingCaptcha = false);
    }
  }

  Future<void> _verify() async {
    final gstin = _gstin.text.trim().toUpperCase();
    if (gstin.length != 15) {
      showMessage(context, 'GSTIN must be 15 characters.', error: true);
      return;
    }
    if (_sessionId == null || _captcha.text.trim().isEmpty) {
      showMessage(context, 'Load the captcha and enter the displayed code.',
          error: true);
      return;
    }
    setState(() => _verifying = true);
    try {
      final data = await widget.api.post('/gst/verify', body: {
        'gstin': gstin,
        'captcha': _captcha.text.trim(),
        'session_id': _sessionId,
      });
      if (mounted)
        setState(() => _result = Map<String, dynamic>.from(data as Map));
    } catch (e) {
      if (mounted) {
        showMessage(context, e.toString(), error: true);
        _loadCaptcha();
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'GSTIN verification',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
              'Verification uses the backend GST service and captcha session. Taxpayer information is returned directly by the server.',
              style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 14),
          Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                    width: 260,
                    child: TextField(
                        controller: _gstin,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 15,
                        decoration: const InputDecoration(
                            labelText: 'GSTIN', counterText: ''))),
                OutlinedButton.icon(
                    onPressed: _loadingCaptcha ? null : _loadCaptcha,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(_captchaImage == null
                        ? 'Load captcha'
                        : 'New captcha')),
                if (_captchaImage != null)
                  Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          border:
                              Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(8)),
                      child: Image.memory(_captchaImage!,
                          width: 170, height: 58, fit: BoxFit.contain)),
                if (_captchaImage != null)
                  SizedBox(
                      width: 160,
                      child: TextField(
                          controller: _captcha,
                          decoration:
                              const InputDecoration(labelText: 'Captcha'))),
                if (_captchaImage != null)
                  FilledButton.icon(
                      onPressed: _verifying ? null : _verify,
                      icon: const Icon(Icons.verified_outlined),
                      label: Text(_verifying ? 'Verifying…' : 'Verify')),
              ]),
          if (_result != null) ...[
            const Divider(height: 28),
            Wrap(spacing: 18, runSpacing: 12, children: [
              _resultTile('Legal name', _result!['legal_name']),
              _resultTile('Trade name', _result!['trade_name']),
              _resultTile('Status', _result!['status']),
              _resultTile('Taxpayer type', _result!['taxpayer_type']),
              _resultTile('Business type', _result!['business_type']),
              _resultTile('Registration date', _result!['registration_date']),
              _resultTile('State code', _result!['state_code']),
              _resultTile('E-invoice status', _result!['e_invoice_status']),
            ]),
            if (_result!['address'] != null)
              Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: SelectableText('Address: ${_result!['address']}')),
          ],
        ]),
      );

  Widget _resultTile(String label, Object? value) => SizedBox(
        width: 260,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 3),
          SelectableText(value?.toString() ?? '—',
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      );
}

class _HsnLookupCard extends StatefulWidget {
  const _HsnLookupCard({required this.api});
  final ApiClient api;

  @override
  State<_HsnLookupCard> createState() => _HsnLookupCardState();
}

class _HsnLookupCardState extends State<_HsnLookupCard> {
  final _code = TextEditingController();
  Map<String, dynamic>? _result;
  bool _loading = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final code = _code.text.trim();
    if (code.length < 6 || code.length > 8 || int.tryParse(code) == null) {
      showMessage(context, 'Enter a 6–8 digit HSN/SAC code.', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await widget.api.get('/gst/hsn/$code');
      if (mounted)
        setState(() => _result = Map<String, dynamic>.from(data as Map));
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'HSN / SAC lookup',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
              'Validate a 6–8 digit HSN/SAC code against the backend directory before using it on GST documents.',
              style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 14),
          Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                    width: 220,
                    child: TextField(
                        controller: _code,
                        keyboardType: TextInputType.number,
                        maxLength: 8,
                        decoration: const InputDecoration(
                            labelText: 'HSN / SAC code', counterText: ''),
                        onSubmitted: (_) => _lookup())),
                FilledButton.icon(
                    onPressed: _loading ? null : _lookup,
                    icon: const Icon(Icons.search_rounded),
                    label: Text(_loading ? 'Looking up…' : 'Lookup')),
              ]),
          if (_result != null) ...[
            const SizedBox(height: 18),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.check_rounded)),
              title: SelectableText(_result!['hsn_code']?.toString() ?? ''),
              subtitle:
                  SelectableText(_result!['description']?.toString() ?? ''),
            ),
          ],
        ]),
      );
}
