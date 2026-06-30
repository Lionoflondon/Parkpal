import 'package:flutter/material.dart';

import 'parkpal_admin_data_service.dart';
import 'parkpal_admin_shell.dart';
import 'parkpal_admin_theme.dart';

class ParkPalAdminApp extends StatelessWidget {
  const ParkPalAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ParkPal Admin',
      debugShowCheckedModeBanner: false,
      theme: buildParkPalAdminTheme(),
      home: const ParkPalAdminAuthGate(),
    );
  }
}

class ParkPalAdminAuthGate extends StatefulWidget {
  const ParkPalAdminAuthGate({super.key});

  @override
  State<ParkPalAdminAuthGate> createState() => _ParkPalAdminAuthGateState();
}

class _ParkPalAdminAuthGateState extends State<ParkPalAdminAuthGate> {
  final _service = ParkPalAdminDataService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _loading = true;
  bool _signingIn = false;
  String? _role;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadRole() async {
    final access = await _service.currentAdminAccess();
    if (!mounted) return;
    setState(() {
      _role = access.role;
      _error = access.reason == 'not_signed_in' ? null : access.message;
      _loading = false;
    });
  }

  Future<void> _signIn() async {
    setState(() {
      _signingIn = true;
      _error = null;
    });

    try {
      final auth = await _service.auth();
      await auth?.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final access = await _service.currentAdminAccess();
      if (!mounted) return;
      setState(() {
        _role = access.role;
        _error = !access.allowed ? access.message : null;
      });
      if (access.bootstrapped && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(access.message)),
        );
      }
    } catch (error, stackTrace) {
      // ignore: avoid_print
      print('ParkPal Admin sign-in failure: $error');
      // ignore: avoid_print
      print(stackTrace);
      if (!mounted) return;
      setState(() => _error = 'Could not sign in to ParkPal Admin.');
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_role != null) {
      return ParkPalAdminShell(role: _role!);
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: adminGlassDecoration(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ParkPal Admin', style: adminHeading(size: 42)),
                const SizedBox(height: 8),
                Text(
                  'Admin-only access for ParkPal operations.',
                  style: adminBody(color: ParkPalAdminColors.muted),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                  onSubmitted: (_) => _signIn(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: adminBody(color: ParkPalAdminColors.red)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _signingIn ? null : _signIn,
                    child: Text(_signingIn ? 'Signing in…' : 'Sign in'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
