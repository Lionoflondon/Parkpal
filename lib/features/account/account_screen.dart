import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/parkpal_theme.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'Guest session';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
      children: [
        Text(
          'Account',
          style: ParkPalText.display(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: ParkPalColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Your ParkPal profile, saved evidence and security controls.',
          style: ParkPalText.body(color: ParkPalColors.muted, fontSize: 15),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: parkPalGlassDecoration(opacity: 0.92, radius: 30),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: parkPalIridescentBorderGradient(),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: ParkPalColors.irisBlue.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ParkPalText.display(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: ParkPalColors.ink,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      user == null
                          ? 'Search history appears after sign-in.'
                          : 'Signed in and ready to save evidence.',
                      style: ParkPalText.body(color: ParkPalColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const _AccountTile(
          icon: Icons.shield_rounded,
          title: 'Evidence protection',
          body: 'Search records are time-stamped for dispute support.',
        ),
        const _AccountTile(
          icon: Icons.notifications_active_rounded,
          title: 'Fine alerts',
          body: 'Smart reminders and permit alerts will appear here.',
        ),
        const _AccountTile(
          icon: Icons.lock_rounded,
          title: 'Privacy',
          body: 'ParkPal only shows real records connected to your account.',
        ),
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: parkPalGlassDecoration(opacity: 0.82, radius: 24),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: ParkPalColors.mint100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: ParkPalColors.green700, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: ParkPalText.body(
                    color: ParkPalColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: ParkPalText.body(
                    color: ParkPalColors.muted,
                    fontSize: 13,
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
