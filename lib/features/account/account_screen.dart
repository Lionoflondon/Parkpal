import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/parkpal_theme.dart';
import '../payments/parkpal_billing_service.dart';

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

    return Semantics(
      label: mode == AccountScreenMode.profile
          ? 'ParkPal profile dashboard'
          : 'ParkPal settings dashboard',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 128),
        children: [
          _ProfileHero(
            name: name,
            username: username,
            email: email,
            photoUrl: user?.photoURL,
            isGuest: user == null,
          ),
          const SizedBox(height: 16),
          if (mode == AccountScreenMode.profile) ...[
            const _QuickStatsBar(),
            const SizedBox(height: 16),
            const _PaymentsSubscriptionSection(),
            const SizedBox(height: 16),
            const _AccountInsightsSection(),
            const SizedBox(height: 16),
            const _VehiclesSection(),
            const SizedBox(height: 16),
            const _FavouritePlacesSection(),
            const SizedBox(height: 16),
            const _ParkingHistorySection(),
            const SizedBox(height: 16),
            const _ReportsSection(),
            const SizedBox(height: 16),
            const _RewardsSection(),
            const SizedBox(height: 16),
            const _TrustExperienceSection(),
          ] else ...[
            const _PremiumSection(
              icon: Icons.notifications_rounded,
              title: 'Notifications',
              subtitle:
                  'Control parking reminders, evidence updates, report outcomes and IRIS alerts.',
              children: [
                _EmptyActionCard(
                  icon: Icons.notifications_active_rounded,
                  title: 'Stay ahead of parking changes',
                  body:
                      'Choose how ParkPal should tell you about expiring checks, report outcomes and new evidence.',
                  cta: 'Configure alerts',
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _PremiumSection(
              icon: Icons.privacy_tip_rounded,
              title: 'Privacy',
              subtitle:
                  'Manage location history, evidence visibility and account data controls.',
              children: [
                _EmptyActionCard(
                  icon: Icons.lock_rounded,
                  title: 'Your evidence stays under your control',
                  body:
                      'Decide what ParkPal stores and when location or evidence history is retained.',
                  cta: 'Review privacy controls',
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _PremiumSection(
              icon: Icons.accessibility_new_rounded,
              title: 'Accessibility',
              subtitle:
                  'Set display, readability and mobility preferences for parking guidance.',
              children: [
                _PreferenceTile(
                  icon: Icons.text_fields_rounded,
                  title: 'Readable labels',
                  value: 'High contrast text enabled',
                ),
                _PreferenceTile(
                  icon: Icons.accessible_rounded,
                  title: 'Mobility context',
                  value: 'Use vehicle profile for accessibility guidance',
                ),
                _PreferenceTile(
                  icon: Icons.motion_photos_off_rounded,
                  title: 'Reduced motion',
                  value: 'Respects device settings',
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _PremiumSection(
              icon: Icons.help_rounded,
              title: 'Help & Support',
              subtitle:
                  'Get support for parking checks, evidence records, reports and appeals.',
              children: [
                _EmptyActionCard(
                  icon: Icons.support_agent_rounded,
                  title: 'No open support requests',
                  body:
                      'If a parking result looks wrong or you need evidence guidance, ParkPal support can review it.',
                  cta: 'Contact ParkPal',
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _PremiumSection(
              icon: Icons.local_parking_rounded,
              title: 'About ParkPal',
              subtitle:
                  'Parking intelligence and evidence — not parking sales, bookings or reservations.',
              children: [
                _PreferenceTile(
                  icon: Icons.auto_awesome_rounded,
                  title: 'IRIS powered',
                  value: 'Certainty before you walk away',
                ),
                _PreferenceTile(
                  icon: Icons.verified_rounded,
                  title: 'Version',
                  value: '0.1.0',
                ),
              ],
            ),
          ],
        ],
      ),
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

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.name,
    required this.username,
    required this.email,
    required this.photoUrl,
    required this.isGuest,
  });

  final String name;
  final String username;
  final String email;
  final String? photoUrl;
  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: parkPalIridescentBorderGradient(),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: ParkPalColors.irisBlue.withValues(alpha: 0.18),
            blurRadius: 42,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ParkPalColors.green900,
              ParkPalColors.navy,
              ParkPalColors.irisBlue.withValues(alpha: 0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(38),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 820;
            final identity = Row(
              children: [
                _Avatar(photoUrl: photoUrl, name: name),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: const [
                          _GlassBadge(
                            icon: Icons.workspace_premium_rounded,
                            label: 'Essential',
                          ),
                          _GlassBadge(
                            icon: Icons.verified_user_rounded,
                            label: 'Trust building',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ParkPalText.display(
                          color: Colors.white,
                          fontSize: wide ? 38 : 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$username  •  $email',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ParkPalText.body(
                          color: Colors.white.withValues(alpha: 0.76),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );

            final trust = _TrustSummaryCard(isGuest: isGuest);
            if (!wide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [identity, const SizedBox(height: 18), trust],
              );
            }
            return Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: 22),
                SizedBox(width: 360, child: trust),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.photoUrl, required this.name});

  final String? photoUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'P' : name.trim()[0].toUpperCase();
    return Semantics(
      label: 'Profile photo',
      image: true,
      child: Container(
        width: 88,
        height: 88,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.34)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(29),
          child: photoUrl == null || photoUrl!.isEmpty
              ? Container(
                  color: ParkPalColors.green700.withValues(alpha: 0.6),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: ParkPalText.display(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                )
              : Image.network(photoUrl!, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _GlassBadge extends StatelessWidget {
  const _GlassBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: ParkPalColors.irisCyan, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: ParkPalText.body(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustSummaryCard extends StatelessWidget {
  const _TrustSummaryCard({required this.isGuest});

  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          'Trust Score 0 percent. Building your reputation. Tap to learn how trust works.',
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => _showTrustSheet(context),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.verified_user_rounded,
                    color: ParkPalColors.irisCyan,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Trust Score',
                      style: ParkPalText.mono(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Icon(Icons.info_outline_rounded,
                      color: Colors.white70, size: 18),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '0%',
                style: ParkPalText.display(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isGuest
                    ? 'Sign in to start building your reputation'
                    : 'Building your reputation',
                style: ParkPalText.body(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: 0.0,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  color: ParkPalColors.irisCyan,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTrustSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: ParkPalColors.cream,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How ParkPal Trust works',
              style: ParkPalText.display(
                color: ParkPalColors.ink,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            const _TrustBullet(
              icon: Icons.add_a_photo_rounded,
              title: 'Verified evidence increases Trust',
              body:
                  'High-quality sign photos, accurate GPS and approved reports improve your score.',
            ),
            const _TrustBullet(
              icon: Icons.rule_rounded,
              title: 'Accuracy matters',
              body:
                  'Rejected, duplicated or unclear submissions do not improve Trust.',
            ),
            const _TrustBullet(
              icon: Icons.workspace_premium_rounded,
              title: 'Higher Trust unlocks stronger influence',
              body:
                  'Trusted contributors help ParkPal prioritise verification and evidence reviews.',
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustBullet extends StatelessWidget {
  const _TrustBullet({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ParkPalColors.green700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: ParkPalText.body(
                        color: ParkPalColors.ink, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(body,
                    style: ParkPalText.body(
                        color: ParkPalColors.muted, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStatsBar extends StatelessWidget {
  const _QuickStatsBar();

  @override
  Widget build(BuildContext context) {
    const stats = [
      _ProfileStat(
        icon: Icons.search_rounded,
        label: 'Parking Checks',
        value: 'Start',
        hint: 'Search a road to begin',
      ),
      _ProfileStat(
        icon: Icons.verified_rounded,
        label: 'Evidence Saved',
        value: 'Ready',
        hint: 'Save proof for disputes',
      ),
      _ProfileStat(
        icon: Icons.report_problem_rounded,
        label: 'Reports Submitted',
        value: 'Help',
        hint: 'Improve local accuracy',
      ),
      _ProfileStat(
        icon: Icons.savings_rounded,
        label: 'Money Saved',
        value: 'Track',
        hint: 'Avoidable fines avoided',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980
            ? 4
            : constraints.maxWidth >= 620
                ? 2
                : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final stat in stats) SizedBox(width: width, child: stat),
          ],
        );
      },
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
  });

  final IconData icon;
  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: parkPalGlassDecoration(opacity: 0.92, radius: 28),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: parkPalIridescentBorderGradient(),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: ParkPalText.display(
                        color: ParkPalColors.ink,
                        fontSize: 24,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(label,
                    style: ParkPalText.body(
                        color: ParkPalColors.ink, fontWeight: FontWeight.w900)),
                Text(hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ParkPalText.body(
                        color: ParkPalColors.muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentsSubscriptionSection extends StatefulWidget {
  const _PaymentsSubscriptionSection();

  @override
  State<_PaymentsSubscriptionSection> createState() =>
      _PaymentsSubscriptionSectionState();
}

class _PaymentsSubscriptionSectionState
    extends State<_PaymentsSubscriptionSection> {
  final _billing = ParkPalBillingService();
  late Future<ParkPalSubscriptionSnapshot?> _subscription;
  bool _loadingAction = false;

  @override
  void initState() {
    super.initState();
    _subscription = _billing.getSubscription();
  }

  Future<void> _refresh() async {
    setState(() => _subscription = _billing.refreshSubscription());
  }

  Future<void> _startCheckout() async {
    await _runBillingAction(
      () => _billing.createCheckoutSession(planKey: 'parkpal_monthly'),
      'Stripe Checkout link copied. Open it in your browser to subscribe.',
    );
  }

  Future<void> _openPortal({bool reactivate = false}) async {
    await _runBillingAction(
      () => _billing.createBillingPortalSession(reactivate: reactivate),
      reactivate
          ? 'Stripe billing portal link copied. Open it to reactivate.'
          : 'Stripe billing portal link copied. Open it to manage billing.',
    );
  }

  Future<void> _runBillingAction(
    Future<ParkPalBillingSession?> Function() action,
    String successMessage,
  ) async {
    if (_loadingAction) return;
    setState(() => _loadingAction = true);
    final session = await action();
    if (!mounted) return;
    setState(() => _loadingAction = false);
    if (session?.url == null) {
      _show('Billing is not available yet. Check Stripe plan configuration.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: session!.url));
    _show(successMessage);
    await _refresh();
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ParkPalSubscriptionSnapshot?>(
      future: _subscription,
      builder: (context, snapshot) {
        final subscription = snapshot.data;
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final isPremium = subscription?.isActive == true;
        final title = subscription == null
            ? 'Upgrade your ParkPal intelligence'
            : subscription.cancelAtPeriodEnd
                ? 'Your subscription will end on ${_date(subscription.currentPeriodEnd)}'
                : subscription.isPastDue
                    ? 'Payment needs attention'
                    : isPremium
                        ? 'Your ParkPal subscription is active'
                        : 'Upgrade your ParkPal intelligence';
        final body = subscription == null
            ? 'Get ongoing access to advanced parking restriction checks, evidence tools, alerts and premium intelligence.'
            : subscription.cancelAtPeriodEnd
                ? 'Your access remains active until the end of the current billing period.'
                : subscription.isPastDue
                    ? 'Update your billing information to keep access to ParkPal premium intelligence.'
                    : isPremium
                        ? 'Plan: ${subscription.planName}. ParkPal keeps your intelligence, evidence and billing state aligned through Stripe.'
                        : 'Get ongoing access to advanced parking restriction checks, evidence tools, alerts and premium intelligence.';

        return Semantics(
          label: 'Payments and subscription centre',
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              gradient: parkPalIridescentBorderGradient(),
              borderRadius: BorderRadius.circular(34),
            ),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ParkPalColors.green900,
                    ParkPalColors.green700,
                    ParkPalColors.irisBlue.withValues(alpha: 0.78),
                  ],
                ),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: ParkPalColors.green700.withValues(alpha: 0.2),
                    blurRadius: 34,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.24)),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Subscription Centre',
                              style: ParkPalText.display(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Software subscription only — ParkPal does not sell or reserve parking.',
                              style: ParkPalText.body(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (loading)
                    const _BillingSkeleton()
                  else ...[
                    Text(
                      title,
                      style: ParkPalText.display(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      body,
                      style: ParkPalText.body(
                        color: Colors.white.withValues(alpha: 0.78),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _BillingInfoGrid(subscription: subscription),
                    const SizedBox(height: 18),
                    const _PlanBenefits(),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (subscription == null || !subscription.isActive)
                          FilledButton.icon(
                            onPressed: _loadingAction ? null : _startCheckout,
                            icon: const Icon(Icons.credit_card_rounded),
                            label: const Text('Choose a monthly plan'),
                          ),
                        if (subscription != null)
                          FilledButton.icon(
                            onPressed:
                                _loadingAction ? null : () => _openPortal(),
                            icon: const Icon(Icons.receipt_long_rounded),
                            label: const Text('Manage Subscription'),
                          ),
                        if (subscription?.cancelAtPeriodEnd == true)
                          OutlinedButton.icon(
                            onPressed: _loadingAction
                                ? null
                                : () => _openPortal(reactivate: true),
                            icon: const Icon(Icons.restart_alt_rounded),
                            label: const Text('Reactivate subscription'),
                          ),
                        OutlinedButton.icon(
                          onPressed: _loadingAction ? null : _refresh,
                          icon: const Icon(Icons.sync_rounded),
                          label: const Text('Restore / refresh'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _date(DateTime? date) {
    if (date == null) return 'shown after Stripe confirms billing';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _BillingSkeleton extends StatelessWidget {
  const _BillingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LinearProgressIndicator(
          color: ParkPalColors.irisCyan,
          backgroundColor: Colors.white.withValues(alpha: 0.18),
        ),
        const SizedBox(height: 16),
        const _SkeletonLine(width: double.infinity),
        const SizedBox(height: 10),
        const _SkeletonLine(width: 240),
      ],
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 16,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _BillingInfoGrid extends StatelessWidget {
  const _BillingInfoGrid({required this.subscription});

  final ParkPalSubscriptionSnapshot? subscription;

  @override
  Widget build(BuildContext context) {
    final items = [
      _BillingInfo('Current Plan', subscription?.planName ?? 'Free access'),
      const _BillingInfo('Monthly allowance', 'Core checks included'),
      const _BillingInfo('Remaining allowance', 'Tracked after activation'),
      _BillingInfo(
        'Renewal date',
        _PaymentsSubscriptionSectionState._date(subscription?.currentPeriodEnd),
      ),
      _BillingInfo('Subscription status', subscription?.status ?? 'Not active'),
      const _BillingInfo('Billing method', 'Managed securely by Stripe'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 3 : 2;
        final width = (constraints.maxWidth - ((columns - 1) * 10)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in items)
              SizedBox(
                width: width < 190 ? constraints.maxWidth : width,
                child: _GlassMetric(label: item.label, value: item.value),
              ),
          ],
        );
      },
    );
  }
}

class _BillingInfo {
  const _BillingInfo(this.label, this.value);

  final String label;
  final String value;
}

class _PlanBenefits extends StatelessWidget {
  const _PlanBenefits();

  @override
  Widget build(BuildContext context) {
    const benefits = [
      'Advanced parking restriction checks',
      'Evidence Vault support',
      'IRIS confidence explanations',
      'Premium alerts and history',
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final benefit in benefits)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: ParkPalColors.irisCyan, size: 17),
                const SizedBox(width: 7),
                Text(
                  benefit,
                  style: ParkPalText.body(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _GlassMetric extends StatelessWidget {
  const _GlassMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: ParkPalText.mono(
              color: Colors.white.withValues(alpha: 0.64),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ParkPalText.body(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountInsightsSection extends StatelessWidget {
  const _AccountInsightsSection();

  @override
  Widget build(BuildContext context) {
    const insights = [
      _InsightTile(Icons.shield_rounded, 'Parking confidence',
          'Confidence will improve as verified checks build up.'),
      _InsightTile(Icons.gavel_rounded, 'Appeals won',
          'Appeal outcomes will appear when evidence is used.'),
      _InsightTile(Icons.savings_rounded, 'Money saved',
          'ParkPal will estimate avoided fine risk from successful checks.'),
      _InsightTile(Icons.verified_rounded, 'Evidence generated',
          'Saved checks and sign reports become your evidence trail.'),
      _InsightTile(Icons.task_alt_rounded, 'Successful checks',
          'Confirmed decisions will appear here over time.'),
      _InsightTile(Icons.trending_up_rounded, 'Monthly activity',
          'Your ParkPal usage rhythm will be tracked here.'),
    ];
    return _PremiumSection(
      icon: Icons.insights_rounded,
      title: 'Account Insights',
      subtitle:
          'A calm command view of the value ParkPal is building around your parking decisions.',
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 920
                ? 3
                : constraints.maxWidth >= 620
                    ? 2
                    : 1;
            final width =
                (constraints.maxWidth - ((columns - 1) * 10)) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final insight in insights)
                  SizedBox(width: width, child: insight),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile(this.icon, this.title, this.body);

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ParkPalColors.mint50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ParkPalColors.greenLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ParkPalColors.green700),
          const SizedBox(height: 10),
          Text(title,
              style: ParkPalText.body(
                  color: ParkPalColors.ink, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(body,
              style: ParkPalText.body(
                  color: ParkPalColors.muted, fontSize: 13, height: 1.35)),
        ],
      ),
    );
  }
}

class _VehiclesSection extends StatelessWidget {
  const _VehiclesSection();

  @override
  Widget build(BuildContext context) {
    return const _PremiumSection(
      icon: Icons.directions_car_rounded,
      title: 'My Vehicles',
      subtitle:
          'Personalise ParkPal guidance with vehicle type, permits and accessibility context.',
      children: [
        _VehicleCard(),
        SizedBox(height: 12),
        _EmptyActionCard(
          icon: Icons.add_road_rounded,
          title: 'Add your vehicle for personalised parking guidance.',
          body:
              'Vehicle details help ParkPal understand permits, loading needs, disabled bay context and restriction relevance.',
          cta: 'Add Vehicle',
        ),
      ],
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ParkPalColors.porcelain,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: ParkPalColors.lineSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: ParkPalColors.mint100,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(Icons.directions_car_rounded,
                color: ParkPalColors.green700, size: 32),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Default vehicle',
                    style: ParkPalText.body(
                        color: ParkPalColors.ink, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                    'Registration, nickname and accessibility notes are ready to add.',
                    style: ParkPalText.body(
                        color: ParkPalColors.muted,
                        height: 1.35,
                        fontSize: 13)),
              ],
            ),
          ),
          const _TinyPill('Default'),
        ],
      ),
    );
  }
}

class _FavouritePlacesSection extends StatelessWidget {
  const _FavouritePlacesSection();

  @override
  Widget build(BuildContext context) {
    return const _PremiumSection(
      icon: Icons.bookmark_rounded,
      title: 'Favourite Places',
      subtitle: 'One-tap checks for the places you park around most often.',
      children: [
        _PlaceGrid(),
        SizedBox(height: 12),
        _EmptyActionCard(
          icon: Icons.add_location_alt_rounded,
          title: 'Save Home and Work for one-tap parking checks.',
          body:
              'Favourite places make ParkPal faster when you are deciding whether it is safe to leave the car.',
          cta: 'Save a place',
        ),
      ],
    );
  }
}

class _PlaceGrid extends StatelessWidget {
  const _PlaceGrid();

  @override
  Widget build(BuildContext context) {
    const places = [
      _PlaceCard(Icons.home_rounded, 'Home', 'Add home'),
      _PlaceCard(Icons.business_center_rounded, 'Work', 'Add work'),
      _PlaceCard(Icons.bookmark_add_rounded, 'Saved Places', 'Build list'),
      _PlaceCard(
          Icons.history_rounded, 'Recently used', 'Appears after checks'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 4 : 2;
        final width = (constraints.maxWidth - ((columns - 1) * 10)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final place in places) SizedBox(width: width, child: place),
          ],
        );
      },
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard(this.icon, this.title, this.action);

  final IconData icon;
  final String title;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ParkPalColors.porcelain,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ParkPalColors.lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ParkPalColors.green700),
          const SizedBox(height: 12),
          Text(title,
              style: ParkPalText.body(
                  color: ParkPalColors.ink, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(action,
              style:
                  ParkPalText.body(color: ParkPalColors.muted, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ParkingHistorySection extends StatelessWidget {
  const _ParkingHistorySection();

  @override
  Widget build(BuildContext context) {
    return const _PremiumSection(
      icon: Icons.history_rounded,
      title: 'Parking History',
      subtitle:
          'Your parking intelligence timeline: checks, trips, evidence, appeals and outcomes.',
      trailing:
          _FilterChips(labels: ['Checks', 'Trips', 'Evidence', 'Appeals']),
      children: [
        _TimelineEmptyCard(),
      ],
    );
  }
}

class _TimelineEmptyCard extends StatelessWidget {
  const _TimelineEmptyCard();

  @override
  Widget build(BuildContext context) {
    return const _EmptyActionCard(
      icon: Icons.timeline_rounded,
      title: 'Your parking intelligence timeline will appear here.',
      body:
          'Search a location, save evidence or submit a report to start building a chronological record.',
      cta: 'Run a parking check',
    );
  }
}

class _ReportsSection extends StatelessWidget {
  const _ReportsSection();

  @override
  Widget build(BuildContext context) {
    return const _PremiumSection(
      icon: Icons.report_problem_rounded,
      title: 'Reports',
      subtitle:
          'Track submissions, verification progress and contribution quality.',
      children: [
        _ProgressRows(
          rows: [
            _ProgressData(
                'Pending verification', 0.0, 'Ready for first report'),
            _ProgressData('Approved', 0.0, 'Approved reports build Trust'),
            _ProgressData('Rejected', 0.0, 'Quality guidance appears here'),
            _ProgressData('Verified signs', 0.0, 'GPS sign reports count here'),
          ],
        ),
        SizedBox(height: 12),
        _EmptyActionCard(
          icon: Icons.add_a_photo_rounded,
          title: 'Help improve parking intelligence by submitting reports.',
          body:
              'Clear photos, measured GPS and accurate context help ParkPal verify local restrictions.',
          cta: 'Submit report',
        ),
      ],
    );
  }
}

class _RewardsSection extends StatelessWidget {
  const _RewardsSection();

  @override
  Widget build(BuildContext context) {
    return const _PremiumSection(
      icon: Icons.workspace_premium_rounded,
      title: 'Rewards',
      subtitle:
          'Progress from careful contributor to trusted Pioneer through verified parking evidence.',
      children: [
        _RewardProgressCard(),
      ],
    );
  }
}

class _RewardProgressCard extends StatelessWidget {
  const _RewardProgressCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ParkPalColors.mint50,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: ParkPalColors.greenLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.military_tech_rounded,
                  color: ParkPalColors.green700),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Current Rank: Starter',
                    style: ParkPalText.body(
                        color: ParkPalColors.ink, fontWeight: FontWeight.w900)),
              ),
              const _TinyPill('0%'),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: const LinearProgressIndicator(
              value: 0,
              minHeight: 10,
              backgroundColor: ParkPalColors.greenLine,
              color: ParkPalColors.safeGreen,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Next milestone: submit your first verified sign or restriction report.',
            style: ParkPalText.body(color: ParkPalColors.muted, height: 1.35),
          ),
          const SizedBox(height: 12),
          const _FilterChips(
            labels: [
              'First sign',
              'Accurate GPS',
              '3-day streak',
              'Local expert'
            ],
          ),
        ],
      ),
    );
  }
}

class _TrustExperienceSection extends StatelessWidget {
  const _TrustExperienceSection();

  @override
  Widget build(BuildContext context) {
    return const _PremiumSection(
      icon: Icons.verified_user_rounded,
      title: 'Trust Experience',
      subtitle:
          'Understand what affects Trust, how to increase it and what higher Trust unlocks.',
      children: [
        _TrustBullet(
          icon: Icons.check_circle_rounded,
          title: 'What affects Trust',
          body:
              'Approved evidence, accurate GPS, useful reports and consistent contribution quality.',
        ),
        _TrustBullet(
          icon: Icons.trending_up_rounded,
          title: 'How to increase it',
          body:
              'Submit clear sign photos, confirm road markings and report temporary restrictions accurately.',
        ),
        _TrustBullet(
          icon: Icons.lock_open_rounded,
          title: 'Benefits of higher Trust',
          body:
              'Higher Trust helps your evidence carry more weight in verification and future Pioneer missions.',
        ),
        _EmptyActionCard(
          icon: Icons.history_edu_rounded,
          title: 'Trust history will appear here.',
          body:
              'ParkPal will show score changes, upcoming rewards and contribution milestones once activity begins.',
          cta: 'Build Trust',
        ),
      ],
    );
  }
}

class _PremiumSection extends StatelessWidget {
  const _PremiumSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: parkPalGlassDecoration(opacity: 0.94, radius: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: ParkPalColors.mint100,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: ParkPalColors.green700, size: 25),
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
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: ParkPalText.body(
                        color: ParkPalColors.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                Flexible(child: trailing!),
              ],
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}

class _EmptyActionCard extends StatelessWidget {
  const _EmptyActionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.cta,
  });

  final IconData icon;
  final String title;
  final String body;
  final String cta;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title $body',
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: () {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
                SnackBar(content: Text('$cta is ready to connect.')));
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: ParkPalColors.porcelain,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: ParkPalColors.lineSoft),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: parkPalIridescentBorderGradient(),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: ParkPalText.body(
                            color: ParkPalColors.ink,
                            fontWeight: FontWeight.w900,
                            height: 1.25)),
                    const SizedBox(height: 5),
                    Text(body,
                        style: ParkPalText.body(
                            color: ParkPalColors.muted,
                            height: 1.38,
                            fontSize: 13)),
                    const SizedBox(height: 12),
                    _ActionPill(label: cta),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ParkPalColors.green700,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: ParkPalText.body(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12)),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward_rounded,
              color: Colors.white, size: 16),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in labels)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: ParkPalColors.mint100,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: ParkPalColors.greenLine),
            ),
            child: Text(
              label,
              style: ParkPalText.body(
                color: ParkPalColors.green700,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

class _ProgressRows extends StatelessWidget {
  const _ProgressRows({required this.rows});

  final List<_ProgressData> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in rows) ...[
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.label,
                        style: ParkPalText.body(
                            color: ParkPalColors.ink,
                            fontWeight: FontWeight.w900)),
                    Text(row.hint,
                        style: ParkPalText.body(
                            color: ParkPalColors.muted, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: row.value,
                    minHeight: 8,
                    backgroundColor: ParkPalColors.greenLine,
                    color: ParkPalColors.safeGreen,
                  ),
                ),
              ),
            ],
          ),
          if (row != rows.last) const Divider(height: 24),
        ],
      ],
    );
  }
}

class _ProgressData {
  const _ProgressData(this.label, this.value, this.hint);

  final String label;
  final double value;
  final String hint;
}

class _PreferenceTile extends StatelessWidget {
  const _PreferenceTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: ParkPalColors.green700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: ParkPalText.body(
                    color: ParkPalColors.ink, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style:
                    ParkPalText.body(color: ParkPalColors.muted, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  const _TinyPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: ParkPalColors.greenBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ParkPalColors.greenLine),
      ),
      child: Text(
        label,
        style: ParkPalText.mono(
          color: ParkPalColors.green700,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
