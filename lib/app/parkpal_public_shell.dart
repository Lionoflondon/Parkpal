import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'parkpal_auth_service.dart';
import 'parkpal_platform_routes.dart';
import 'parkpal_theme.dart';

class ParkPalPublicShell extends StatefulWidget {
  const ParkPalPublicShell({
    required this.routeName,
    this.authService,
    super.key,
  });

  final String routeName;
  final ParkPalAuthService? authService;

  @override
  State<ParkPalPublicShell> createState() => _ParkPalPublicShellState();
}

class _ParkPalPublicShellState extends State<ParkPalPublicShell> {
  late String _routeName = widget.routeName;

  void _go(String route) {
    setState(() => _routeName = route);
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final showAuth = _routeName == ParkPalPlatformRoutes.signIn ||
        _routeName == ParkPalPlatformRoutes.createAccount ||
        (ParkPalPlatformRoutes.isAppRoute(_routeName) &&
            _routeName != ParkPalPlatformRoutes.iris);

    return Scaffold(
      body: Stack(
        children: [
          const _PublicBackdrop(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 52),
              children: [
                _PublicHeader(currentRoute: _routeName, onNavigate: _go),
                const SizedBox(height: 34),
                if (showAuth)
                  _AuthPanel(
                    createAccount:
                        _routeName == ParkPalPlatformRoutes.createAccount,
                    authService: widget.authService,
                  )
                else
                  _PublicContent(routeName: _routeName, onNavigate: _go),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicHeader extends StatelessWidget {
  const _PublicHeader({required this.currentRoute, required this.onNavigate});

  final String currentRoute;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 860;
    final links = [
      ('Home', ParkPalPlatformRoutes.home),
      ('Features', ParkPalPlatformRoutes.features),
      ('IRIS', ParkPalPlatformRoutes.iris),
      ('Atlas', ParkPalPlatformRoutes.atlas),
      ('Pioneer', ParkPalPlatformRoutes.pioneer),
      ('Business', ParkPalPlatformRoutes.business),
      ('Support', ParkPalPlatformRoutes.support),
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: wide ? 22 : 16, vertical: 14),
      decoration: parkPalGlassDecoration(opacity: 0.9, radius: 28),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _LogoMark(),
              const SizedBox(width: 10),
              Text(
                'ParkPal',
                style: ParkPalText.display(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: ParkPalColors.ink,
                ),
              ),
            ],
          ),
          if (wide)
            for (final link in links)
              _NavChip(
                label: link.$1,
                selected: currentRoute == link.$2,
                onTap: () => onNavigate(link.$2),
              ),
          if (!wide)
            PopupMenuButton<String>(
              onSelected: onNavigate,
              itemBuilder: (_) => [
                for (final link in links)
                  PopupMenuItem(value: link.$2, child: Text(link.$1)),
              ],
              child: const Icon(Icons.menu_rounded),
            ),
          OutlinedButton(
            onPressed: () => onNavigate(ParkPalPlatformRoutes.signIn),
            child: const Text('Sign In'),
          ),
          FilledButton(
            onPressed: () => onNavigate(ParkPalPlatformRoutes.createAccount),
            child: const Text('Create Account'),
          ),
        ],
      ),
    );
  }
}

class _PublicContent extends StatelessWidget {
  const _PublicContent({required this.routeName, required this.onNavigate});

  final String routeName;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final copy = switch (routeName) {
      ParkPalPlatformRoutes.features => (
          'Features',
          'Parking intelligence, evidence records, sign certainty and map-led guidance in one calm platform.',
          'Explore live checks, saved evidence, reports, notifications and Pioneer contributions.',
        ),
      ParkPalPlatformRoutes.iris => (
          'IRIS',
          'The ParkPal intelligence layer for signs, council rules, Atlas evidence and uncertainty.',
          'IRIS explains why a parking answer is safe, risky or unknown without inventing confidence.',
        ),
      ParkPalPlatformRoutes.atlas => (
          'Atlas',
          'A living parking intelligence map built from official data, verified signs and field evidence.',
          'Atlas explains what ParkPal knows, how confident it is, and what evidence supports the answer.',
        ),
      ParkPalPlatformRoutes.pioneer => (
          'Pioneer',
          'Help verify streets, signs and changing restrictions across the UK.',
          'Pioneer missions turn local checks into better parking certainty.',
        ),
      ParkPalPlatformRoutes.business => (
          'Business',
          'Parking certainty for couriers, tradespeople, riders and fleets.',
          'Reduce tickets, wasted time and operational uncertainty with ParkPal intelligence.',
        ),
      ParkPalPlatformRoutes.support => (
          'Support',
          'Evidence-first help for unclear restrictions, reports and appeal preparation.',
          'ParkPal keeps every check transparent and time-stamped.',
        ),
      _ => (
          'Certainty before you walk away.',
          'Know before you park.',
          'Search a road, check restrictions, save evidence and let IRIS explain the confidence behind every parking answer.',
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: parkPalGlassDecoration(opacity: 0.94, radius: 38),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                copy.$1,
                style: ParkPalText.display(
                  fontSize: 52,
                  height: 0.95,
                  fontWeight: FontWeight.w900,
                  color: ParkPalColors.ink,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                copy.$2,
                style: ParkPalText.body(
                  fontSize: 20,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: ParkPalColors.graphite,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                copy.$3,
                style: ParkPalText.body(
                  fontSize: 15,
                  height: 1.6,
                  color: ParkPalColors.muted,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () =>
                        onNavigate(ParkPalPlatformRoutes.createAccount),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Create Account'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onNavigate(ParkPalPlatformRoutes.signIn),
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Sign In'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 760;
            final cards = const [
              _PublicFeatureCard(
                icon: Icons.map_rounded,
                title: 'Live Map',
                body: 'See Atlas-backed parking intelligence by street.',
              ),
              _PublicFeatureCard(
                icon: Icons.auto_awesome_rounded,
                title: 'IRIS Answers',
                body: 'Understand confidence, sources and risk before parking.',
              ),
              _PublicFeatureCard(
                icon: Icons.folder_copy_rounded,
                title: 'Evidence Vault',
                body: 'Keep time-stamped records for dispute support.',
              ),
            ];
            if (!wide) return Column(children: cards);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 14),
                Expanded(child: cards[1]),
                const SizedBox(width: 14),
                Expanded(child: cards[2]),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AuthPanel extends StatefulWidget {
  const _AuthPanel({required this.createAccount, this.authService});

  final bool createAccount;
  final ParkPalAuthService? authService;

  @override
  State<_AuthPanel> createState() => _AuthPanelState();
}

class _AuthPanelState extends State<_AuthPanel> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;
  final List<String> _authTrace = [];

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.length < 7) {
      setState(
        () =>
            _error = 'Enter an email and a password of at least 7 characters.',
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _authTrace.clear();
    });
    try {
      _addAuthTrace('submit(): started. authDebug=$_authDebugEnabled');
      _addAuthTrace('submit(): Uri=${Uri.base}');
      _addAuthTrace('submit(): route=${ModalRoute.of(context)?.settings.name}');
      final auth = widget.authService ?? ParkPalAuthService();
      if (widget.createAccount) {
        _addAuthTrace('submit(): createAccount path selected');
        await auth.createAccount(email: _email.text, password: _password.text);
      } else {
        _addAuthTrace('submit(): signIn path selected');
        await auth.signIn(
          email: _email.text,
          password: _password.text,
          trace: _addAuthTrace,
        );
      }
      _addAuthTrace('submit(): auth call completed without throwing');
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacementNamed(ParkPalPlatformRoutes.dashboard);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        if (error is FirebaseAuthException) {
          debugPrint(
            'ParkPal auth panel FirebaseAuthException: '
            'code=${error.code}, message=${error.message}, '
            'runtimeType=${error.runtimeType}',
          );
        } else {
          debugPrint(
            'ParkPal auth panel raw exception: '
            'runtimeType=${error.runtimeType}, value=$error',
          );
        }
        debugPrint('ParkPal auth panel stack trace: $stackTrace');
      }
      if (!mounted) return;
      setState(() => _error = _friendlyAuthError(error, stackTrace));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: parkPalGlassDecoration(opacity: 0.96, radius: 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.createAccount
                    ? 'Create your ParkPal account'
                    : 'Sign in to ParkPal',
                style: ParkPalText.display(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: ParkPalColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The site becomes your ParkPal application after sign-in — same domain, different shell.',
                style: ParkPalText.body(
                  color: ParkPalColors.muted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(labelText: 'Password'),
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: ParkPalText.body(color: ParkPalColors.red),
                ),
              ],
              if (kDebugMode && _authDebugEnabled && _authTrace.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ParkPalColors.ink.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ParkPalColors.line),
                  ),
                  child: Text(
                    'Auth trace\n${_authTrace.join('\n')}',
                    style: ParkPalText.mono(
                      fontSize: 11,
                      color: ParkPalColors.ink,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: Text(
                    _loading
                        ? 'Please wait…'
                        : widget.createAccount
                            ? 'Create Account'
                            : 'Sign In',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _friendlyAuthError(Object error, StackTrace stackTrace) {
    final friendly = _friendlyAuthMessage(error);
    if (!kDebugMode) return friendly;

    if (error is FirebaseAuthException) {
      return '$friendly\n\nDebug FirebaseAuthException\n'
          'Code: ${error.code}\n'
          'Message: ${error.message ?? 'No message provided.'}\n'
          'Runtime type: ${error.runtimeType}\n'
          'Stack trace:\n$stackTrace';
    }

    return '$friendly\n\nDebug raw exception\n'
        'Runtime type: ${error.runtimeType}\n'
        'Value: $error\n'
        'Stack trace:\n$stackTrace';
  }

  String _friendlyAuthMessage(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' =>
          'Email or password is incorrect.',
        'invalid-email' => 'Enter a valid email address.',
        'email-already-in-use' => 'This email already has a ParkPal account.',
        'weak-password' => 'Choose a stronger password.',
        'network-request-failed' => 'Network error. Please try again.',
        'too-many-requests' =>
          'Too many attempts. Wait a moment, then try again.',
        'user-disabled' => 'This ParkPal account has been disabled.',
        'operation-not-allowed' =>
          'Email/password sign-in is not enabled for this Firebase project.',
        'unauthorized-domain' =>
          'This domain is not authorised for ParkPal sign-in.',
        'web-storage-unsupported' =>
          'This browser is blocking the storage ParkPal needs to keep you signed in.',
        _ => 'ParkPal could not authenticate this account.',
      };
    }

    return 'ParkPal could not authenticate this account.';
  }

  bool get _authDebugEnabled => Uri.base.queryParameters['authDebug'] == '1';

  void _addAuthTrace(String message) {
    final line = '${DateTime.now().toIso8601String()}  $message';
    if (kDebugMode) {
      debugPrint('ParkPal auth trace: $line');
    }
    if (!mounted) {
      _authTrace.add(line);
      return;
    }
    setState(() => _authTrace.add(line));
  }
}

class _PublicFeatureCard extends StatelessWidget {
  const _PublicFeatureCard({
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
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: parkPalGlassDecoration(opacity: 0.88, radius: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ParkPalColors.green700, size: 30),
          const SizedBox(height: 16),
          Text(
            title,
            style: ParkPalText.display(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: ParkPalColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(body, style: ParkPalText.body(color: ParkPalColors.muted)),
        ],
      ),
    );
  }
}

class _NavChip extends StatelessWidget {
  const _NavChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? ParkPalColors.mint100 : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: ParkPalText.body(
            color: selected ? ParkPalColors.green700 : ParkPalColors.muted,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: parkPalIridescentBorderGradient(),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: ParkPalColors.irisBlue.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'P',
          style: ParkPalText.display(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
      ),
    );
  }
}

class _PublicBackdrop extends StatelessWidget {
  const _PublicBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ParkPalColors.cream,
            ParkPalColors.mint50,
            ParkPalColors.porcelain,
          ],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}
