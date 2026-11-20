import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../admin/parkpal_admin_theme.dart';

class ParkPalRothRewardsScreen extends StatefulWidget {
  const ParkPalRothRewardsScreen({super.key});

  @override
  State<ParkPalRothRewardsScreen> createState() => _ParkPalRothRewardsScreenState();
}

class _ParkPalRothRewardsScreenState extends State<ParkPalRothRewardsScreen> {
  final _customer = TextEditingController();
  final _rewardReference = TextEditingController();
  final _campaign = TextEditingController();
  final _reason = TextEditingController();
  bool _working = false;
  String? _message;
  String _program = 'subscription';

  @override
  void dispose() {
    _customer.dispose();
    _rewardReference.dispose();
    _campaign.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _issue() async {
    final customerUid = _customer.text.trim();
    final rewardId = _rewardReference.text.trim();
    final campaignId = _campaign.text.trim();
    final reason = _reason.text.trim();
    if (customerUid.isEmpty || rewardId.isEmpty || campaignId.isEmpty || reason.isEmpty) {
      setState(() => _message = 'Enter a linked ParkPal customer, verified eligibility reference, campaign and reason.');
      return;
    }
    setState(() { _working = true; _message = null; });
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'europe-west2')
          .httpsCallable('issueParkPalRothReward')
          .call<Map<String, dynamic>>({
            'customerUid': customerUid,
            'rewardId': rewardId,
            'program': _program,
            'campaignId': campaignId,
            'reason': reason,
          });
      if (mounted) {
        setState(() {
          _message = 'ROTH recorded reward ${result.data['journalId'] ?? ''}.';
        });
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        setState(() => _message = error.message ?? 'The ROTH reward could not be issued.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'The ROTH reward could not be issued.');
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!const bool.fromEnvironment('PARKPAL_ROTH_ENABLED') ||
        const String.fromEnvironment('PARKPAL_ENV') != 'staging') {
      return const Center(child: Text('ROTH rewards are disabled in this build.'));
    }
    return ListView(
      children: [
        Text('ROTH Rewards', style: adminHeading(size: 42)),
        const SizedBox(height: 8),
        Text('Reward values and limits come from the approved staging policy. Subscription rewards require verified paid invoice evidence and remain disabled until ROTH supports approved reversals for refunds and cancellations.', style: adminBody(color: ParkPalAdminColors.muted)),
        const SizedBox(height: 24),
        TextField(controller: _customer, decoration: const InputDecoration(labelText: 'Linked ParkPal customer UID')),
        DropdownButtonFormField<String>(
          value: _program,
          decoration: const InputDecoration(labelText: 'Reward programme'),
          items: const [
            DropdownMenuItem(value: 'subscription', child: Text('Subscription')),
            DropdownMenuItem(value: 'referral', child: Text('Referral')),
            DropdownMenuItem(value: 'promotion', child: Text('Promotion')),
          ],
          onChanged: _working ? null : (value) { if (value != null) setState(() => _program = value); },
        ),
        TextField(controller: _rewardReference, decoration: const InputDecoration(labelText: 'Verified eligibility reference (invoice ID for subscriptions)')),
        TextField(controller: _campaign, decoration: const InputDecoration(labelText: 'Authorised campaign ID')),
        TextField(controller: _reason, decoration: const InputDecoration(labelText: 'Reason / eligibility reference')),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _working ? null : _issue,
            icon: const Icon(Icons.add_card),
            label: Text(_working ? 'Posting…' : 'Issue ParkPal ROTH reward'),
          ),
        ),
        if (_message != null) Padding(padding: const EdgeInsets.only(top: 16), child: SelectableText(_message!)),
      ],
    );
  }
}
