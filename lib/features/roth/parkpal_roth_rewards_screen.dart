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
  final _amount = TextEditingController();
  final _campaign = TextEditingController();
  final _reason = TextEditingController();
  bool _working = false;
  String? _message;
  String? _pendingRewardId;

  @override
  void dispose() {
    _customer.dispose();
    _amount.dispose();
    _campaign.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _issue() async {
    final customerUid = _customer.text.trim();
    final campaignId = _campaign.text.trim();
    final reason = _reason.text.trim();
    final parsedAmount = int.tryParse(_amount.text.trim());
    if (customerUid.isEmpty || campaignId.isEmpty || reason.isEmpty || parsedAmount == null || parsedAmount < 1 || parsedAmount > 100000) {
      setState(() => _message = 'Enter a ParkPal customer account, campaign, reason and amount from 1 to 100,000 pence.');
      return;
    }
    setState(() { _working = true; _message = null; });
    final rewardId = _pendingRewardId ??= 'parkpal-${DateTime.now().microsecondsSinceEpoch}';
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'europe-west2')
          .httpsCallable('issueParkPalRothReward')
          .call<Map<String, dynamic>>({
            'customerUid': customerUid,
            'rewardId': rewardId,
            'amountPence': parsedAmount,
            'campaignId': campaignId,
            'reason': reason,
          });
      if (mounted) {
        setState(() {
          _message = 'ROTH recorded reward ${result.data['journalId'] ?? ''}.';
          _pendingRewardId = null;
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
        Text('Independent ParkPal issuance posts directly to the central ROTH ledger. Only issue rewards authorised under a documented ParkPal campaign; the central ledger enforces the company allowance and idempotency.', style: adminBody(color: ParkPalAdminColors.muted)),
        const SizedBox(height: 24),
        TextField(controller: _customer, decoration: const InputDecoration(labelText: 'Linked ParkPal customer UID')),
        TextField(controller: _amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Reward amount (integer pence)')),
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
