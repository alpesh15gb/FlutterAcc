import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    required this.child,
    this.maxWidth = 1480,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: actions.isEmpty ? double.infinity : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(subtitle!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.muted)),
                        ],
                      ],
                    ),
                  ),
                  ...actions,
                ],
              ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard(
      {super.key,
      this.title,
      this.trailing,
      required this.child,
      this.padding = const EdgeInsets.all(16)});
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null || trailing != null) ...[
              Row(children: [
                if (title != null)
                  Expanded(
                      child: Text(title!,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16))),
                if (trailing != null) trailing!,
              ]),
              const SizedBox(height: 14),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard(
      {super.key,
      required this.label,
      required this.value,
      required this.icon,
      this.caption,
      this.tone});
  final String label;
  final String value;
  final IconData icon;
  final String? caption;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final color = tone ?? AppColors.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withOpacity(.09),
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, color: color, size: 20),
            ),
            const Spacer(),
            if (caption != null)
              Text(caption!,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ]),
          const SizedBox(height: 14),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ]),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.message,
      this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(children: [
              Icon(icon, size: 42, color: AppColors.muted),
              const SizedBox(height: 12),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 6),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted)),
              if (action != null) ...[const SizedBox(height: 16), action!],
            ]),
          ),
        ),
      );
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.danger),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Retry')),
          ]),
        ),
      );
}

Future<DateTime?> pickDate(BuildContext context, DateTime initial) {
  return showDatePicker(
    context: context,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
    initialDate: initial,
  );
}

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: error ? AppColors.danger : null,
  ));
}
