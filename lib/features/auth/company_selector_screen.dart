import 'package:flutter/material.dart';

import '../../core/session/session_controller.dart';
import '../../core/theme/app_theme.dart';

class CompanySelectorScreen extends StatelessWidget {
  const CompanySelectorScreen({super.key, required this.session});
  final SessionController session;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Choose company'),
          actions: [
            TextButton.icon(
                onPressed: session.logout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'))
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Welcome${session.userName == null ? '' : ', ${session.userName}'}',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    const Text(
                        'Select the GST/business entity you want to work in.',
                        style: TextStyle(color: AppColors.muted)),
                    const SizedBox(height: 20),
                    if (session.memberships.isEmpty)
                      const Card(
                          child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                  'No active company memberships were returned for this account.')))
                    else
                      ...session.memberships.map((membership) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 8),
                                leading: const CircleAvatar(
                                    child: Icon(Icons.business_rounded)),
                                title: Text(membership.tenantName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                                subtitle: Text(membership.role),
                                trailing: const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 17),
                                onTap: () => session.selectCompany(membership),
                              ),
                            ),
                          )),
                  ]),
            ),
          ),
        ),
      );
}
