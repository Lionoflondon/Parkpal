import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/parkpal_theme.dart';

enum AccountScreenMode { profile, settings }

class AccountScreen extends StatelessWidget {
  const AccountScreen({
    this.mode = AccountScreenMode.profile,
    super.key,
  });

  final AccountScreenMode mode;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'Guest session';
    final name = _displayName(user);
    final username = _usernameFrom(email);

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 128),
      children: [
        _ProfileHeader(
          name: name,
          username: username,
          email: email,
          isGuest: user == null,
        ),
        const SizedBox(height: 18),
        if (mode == AccountScreenMode.profile) ...[
          const _ProfileSection(
            icon: Icons.directions_car_rounded,
            title: 'My Vehicles',
            body:
                'Add your vehicle, permits, accessibility needs and default parking context.',
            actions: ['Add vehicle', 'Edit vehicle', 'Default vehicle'],
            emptyState: 'No vehicles saved yet.',
          ),
          const _ProfileSection(
            icon: Icons.bookmark_rounded,
            title: 'Favourite Places',
            body:
                'Save home, work and frequent stops so ParkPal can surface faster checks.',
            actions: ['Home', 'Work', 'Saved locations'],
            emptyState: 'No favourite places yet.',
          ),
          const _ProfileSection(
            icon: Icons.history_rounded,
            title: 'Parking History',
            body:
                'Review previous parking checks, trips and saved evidence records.',
            actions: ['Previous checks', 'Trips', 'Saved evidence'],
            emptyState: 'No parking checks yet.',
          ),
          const _ProfileSection(
            icon: Icons.report_problem_rounded,
            title: 'Reports',
            body:
                'Track submitted reports, contributions and verified sign outcomes.',
            actions: ['Submitted reports', 'Contributions', 'Verified signs'],
            emptyState: 'No reports submitted.',
          ),
          const _ProfileSection(
            icon: Icons.verified_user_rounded,
            title: 'Rewards',
            body:
                'Follow Pioneer level, badges, contribution quality and trust progression.',
            actions: ['Pioneer level', 'Badges', 'Contributions'],
            emptyState: 'No rewards earned yet.',
          ),
        ] else ...[
          const _ProfileSection(
            icon: Icons.notifications_rounded,
            title: 'Notifications',
            body:
                'Control parking reminders, evidence updates, report outcomes and IRIS alerts.',
            actions: ['Parking alerts', 'Evidence updates', 'Report outcomes'],
            emptyState: 'Notifications are ready to configure.',
          ),
          const _ProfileSection(
            icon: Icons.privacy_tip_rounded,
            title: 'Privacy',
            body:
                'Manage location history, evidence visibility and account data controls.',
            actions: ['Location history', 'Evidence visibility', 'Data export'],
            emptyState: 'Privacy controls are available after sign-in.',
          ),
          const _ProfileSection(
            icon: Icons.accessibility_new_rounded,
            title: 'Accessibility',
            body:
                'Set display, readability and mobility preferences for parking guidance.',
            actions: ['Readable labels', 'Mobility context', 'Reduced motion'],
            emptyState: 'Accessibility preferences are ready.',
          ),
          const _ProfileSection(
            icon: Icons.settings_rounded,
            title: 'Settings',
            body:
                'Manage app preferences, default vehicle context and evidence settings.',
            actions: [
              'App preferences',
              'Default context',
              'Evidence settings'
            ],
            emptyState: 'No custom settings saved yet.',
          ),
          const _ProfileSection(
            icon: Icons.help_rounded,
            title: 'Help & Support',
            body:
                'Get support for parking checks, evidence records, reports and appeals.',
            actions: ['Support centre', 'Appeal guidance', 'Contact ParkPal'],
            emptyState: 'No open support requests.',
          ),
          const _ProfileSection(
            icon: Icons.local_parking_rounded,
            title: 'About ParkPal',
            body:
                'ParkPal is a parking intelligence and evidence platform. It does not sell parking spaces or take bookings.',
            actions: ['Version 0.1.0', 'Know before you park', 'IRIS powered'],
            emptyState: 'Certainty before you walk away.',
          ),
        ],
      ],
    );
  }

  static String _displayName(User? user) {
    final name = user?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = user?.email;
    if (email == null || email.isEmpty) return 'ParkPal driver';
    return email.split('@').first;
  }

  static String _usernameFrom(String email) {
    if (!email.contains('@')) return '@parkpal';
    return '@${email.split('@').first}';
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.username,
    required this.email,
    required this.isGuest,
  });

  final String name;
  final String username;
  final String email;
  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ParkPalColors.green900,
            ParkPalColors.navy,
            ParkPalColors.irisBlue.withValues(alpha: 0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(38),
        boxShadow: [
          BoxShadow(
            color: ParkPalColors.irisBlue.withValues(alpha: 0.16),
            blurRadius: 34,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final identity = Row(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(28),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.28)),
                ),
                child: const Icon(
                  Icons.account_circle_rounded,
                  color: Colors.white,
                  size: 44,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ParkPalText.display(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$username • $email',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ParkPalText.body(
                        color: Colors.white.withValues(alpha: 0.76),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final stats = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeaderMetric(
                icon: Icons.event_available_rounded,
                label: 'Membership since',
                value: isGuest ? 'After sign-in' : '2026',
              ),
              const _HeaderMetric(
                icon: Icons.verified_user_rounded,
                label: 'Trust score',
                value: '0%',
              ),
              const _HeaderMetric(
                icon: Icons.workspace_premium_rounded,
                label: 'Pioneer level',
                value: 'Starter',
              ),
            ],
          );

          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [identity, const SizedBox(height: 18), stats],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: identity),
              const SizedBox(width: 20),
              Flexible(child: stats),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(icon, color: ParkPalColors.irisCyan, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: ParkPalText.body(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ParkPalText.mono(
                    color: Colors.white.withValues(alpha: 0.66),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.icon,
    required this.title,
    required this.body,
    required this.actions,
    required this.emptyState,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<String> actions;
  final String emptyState;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: parkPalGlassDecoration(opacity: 0.9, radius: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: ParkPalColors.mint100,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: ParkPalColors.green700, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: ParkPalText.display(
                        color: ParkPalColors.ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: ParkPalText.body(
                        color: ParkPalColors.muted,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ParkPalColors.mint50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ParkPalColors.greenLine),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_rounded,
                  color: ParkPalColors.green700,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    emptyState,
                    style: ParkPalText.body(
                      color: ParkPalColors.graphite,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final action in actions)
                _ActionChip(label: action, icon: _iconForAction(action)),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconForAction(String action) {
    final lower = action.toLowerCase();
    if (lower.contains('vehicle')) return Icons.directions_car_rounded;
    if (lower.contains('home')) return Icons.home_rounded;
    if (lower.contains('work')) return Icons.business_center_rounded;
    if (lower.contains('trip')) return Icons.route_rounded;
    if (lower.contains('evidence')) return Icons.verified_rounded;
    if (lower.contains('report')) return Icons.report_problem_rounded;
    if (lower.contains('sign')) return Icons.traffic_rounded;
    if (lower.contains('badge') || lower.contains('level')) {
      return Icons.workspace_premium_rounded;
    }
    if (lower.contains('notification') || lower.contains('alert')) {
      return Icons.notifications_rounded;
    }
    if (lower.contains('privacy') || lower.contains('data')) {
      return Icons.privacy_tip_rounded;
    }
    if (lower.contains('support') || lower.contains('contact')) {
      return Icons.help_rounded;
    }
    if (lower.contains('version')) return Icons.info_rounded;
    return Icons.chevron_right_rounded;
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ParkPalColors.lineSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: ParkPalColors.green700),
          const SizedBox(width: 7),
          Text(
            label,
            style: ParkPalText.body(
              color: ParkPalColors.green700,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
