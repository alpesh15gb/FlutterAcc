import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.get('/reminders');
      if (!mounted) return;
      setState(() {
        _items = data is List
            ? data.map((e) => Map<String, dynamic>.from(e as Map)).toList()
            : [];
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _acknowledge() async {
    try {
      final result = await widget.api.post('/reminders');
      if (!mounted) return;
      final message = result is Map ? result['message']?.toString() : null;
      showMessage(context, message ?? 'Reminders acknowledged.');
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Reminders & Daily Summary',
    subtitle: 'Live overdue collection reminders and today’s sales, receipts and purchase/bill summary.',
    actions: [
      IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
      OutlinedButton.icon(
        onPressed: _items.isEmpty ? null : _acknowledge,
        icon: const Icon(Icons.done_all_rounded),
        label: const Text('Acknowledge'),
      ),
    ],
    child: _loading
        ? const Padding(
            padding: EdgeInsets.all(60),
            child: Center(child: CircularProgressIndicator()),
          )
        : _error != null
        ? ErrorPanel(message: _error!, onRetry: _load)
        : _items.isEmpty
        ? const EmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'Nothing needs attention',
            message: 'Live overdue reminders and the daily business summary will appear here.',
          )
        : Column(
            children: _items.map((item) {
              final title = '${item['title'] ?? 'Reminder'}';
              final overdue = title.toLowerCase().contains('overdue');
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SectionCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color:
                              (overdue ? AppColors.danger : AppColors.primary)
                                  .withOpacity(.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          overdue
                              ? Icons.notification_important_outlined
                              : Icons.summarize_outlined,
                          color: overdue ? AppColors.danger : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${item['message'] ?? ''}',
                              style: const TextStyle(
                                color: AppColors.muted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
  );
}
