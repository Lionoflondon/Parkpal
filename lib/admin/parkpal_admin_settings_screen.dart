import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'parkpal_admin_data_service.dart';
import 'parkpal_admin_theme.dart';

class ParkPalAdminSettingsScreen extends StatefulWidget {
  const ParkPalAdminSettingsScreen({super.key});

  @override
  State<ParkPalAdminSettingsScreen> createState() =>
      _ParkPalAdminSettingsScreenState();
}

class _ParkPalAdminSettingsScreenState
    extends State<ParkPalAdminSettingsScreen> {
  final _service = ParkPalAdminDataService();
  late Future<ParkPalOperationalSettingsResult> _settings;
  Map<String, Object?> _data = {};
  String _saveStatus = 'Loaded';
  String? _validation;

  @override
  void initState() {
    super.initState();
    _settings = _load();
  }

  Future<ParkPalOperationalSettingsResult> _load() async {
    final result = await _service.loadOperationalSettings();
    if (mounted && result.loaded) {
      setState(() => _data = Map<String, Object?>.from(result.data));
    }
    return result;
  }

  Future<void> _save(String field, Object? value) async {
    setState(() {
      _data[field] = value;
      _saveStatus = 'Saving…';
      _validation = _validate(field, value);
    });
    if (_validation != null) {
      setState(() => _saveStatus = 'Validation needed');
      return;
    }
    final ok = await _service.saveOperationalSetting(field, value);
    if (!mounted) return;
    setState(() => _saveStatus = ok ? 'Saved' : 'Unable to save');
  }

  String? _validate(String field, Object? value) {
    if (field.contains('Minutes') && ((value as int?) ?? 0) < 0) {
      return 'Minute values cannot be negative.';
    }
    if (field == 'platformFeePercent') {
      final number = (value as num?)?.toDouble() ?? 0;
      if (number < 0 || number > 100) {
        return 'Platform fee must be between 0 and 100.';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ParkPalOperationalSettingsResult>(
      future: _settings,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final result = snapshot.data;
        if (result == null || !result.loaded) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: adminGlassDecoration(),
              child: Text(
                'Unable to load settings. Please try again.',
                style: adminBody(color: ParkPalAdminColors.red),
              ),
            ),
          );
        }

        return ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Settings', style: adminHeading(size: 46)),
                ),
                Text(_saveStatus,
                    style: adminBody(color: ParkPalAdminColors.cyan)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'ParkPal operational control centre. Settings autosave to Firestore.',
              style: adminBody(color: ParkPalAdminColors.muted),
            ),
            const SizedBox(height: 12),
            Text(
              'Last updated: ${_dateLabel(_data['updatedAt'])} • Updated by: ${_data['updatedBy'] ?? 'ParkPal Admin'}',
              style: adminBody(color: ParkPalAdminColors.muted, size: 12),
            ),
            if (_validation != null) ...[
              const SizedBox(height: 8),
              Text(_validation!,
                  style: adminBody(color: ParkPalAdminColors.amber)),
            ],
            const SizedBox(height: 22),
            _SettingsSection(
              title: 'Operations',
              children: [
                _NumberSetting(
                  label: 'Maximum parking duration',
                  suffix: 'minutes',
                  value: _int('maximumParkingDurationMinutes'),
                  onChanged: (value) =>
                      _save('maximumParkingDurationMinutes', value),
                ),
                _NumberSetting(
                  label: 'Grace period',
                  suffix: 'minutes',
                  value: _int('gracePeriodMinutes'),
                  onChanged: (value) => _save('gracePeriodMinutes', value),
                ),
                _TextSetting(
                  label: 'Cancellation rules',
                  value: _string('cancellationRules'),
                  onChanged: (value) => _save('cancellationRules', value),
                ),
                _SwitchSetting(
                  label: 'Booking extensions',
                  value: _bool('bookingExtensionsEnabled'),
                  onChanged: (value) =>
                      _save('bookingExtensionsEnabled', value),
                ),
                _SwitchSetting(
                  label: 'Auto release expired bookings',
                  value: _bool('autoReleaseExpiredBookings'),
                  onChanged: (value) =>
                      _save('autoReleaseExpiredBookings', value),
                ),
              ],
            ),
            _SettingsSection(
              title: 'Payments',
              children: [
                _TextSetting(
                  label: 'Stripe status',
                  value: _string('stripeStatus'),
                  onChanged: (value) => _save('stripeStatus', value),
                ),
                _TextSetting(
                  label: 'Refund policy',
                  value: _string('refundPolicy'),
                  onChanged: (value) => _save('refundPolicy', value),
                ),
                _NumberSetting(
                  label: 'Platform fee',
                  suffix: '%',
                  value: _int('platformFeePercent'),
                  onChanged: (value) => _save('platformFeePercent', value),
                ),
                _TextSetting(
                  label: 'Taxes',
                  value: _string('taxes'),
                  onChanged: (value) => _save('taxes', value),
                ),
                _TextSetting(
                  label: 'Default currency',
                  value: _string('defaultCurrency'),
                  onChanged: (value) => _save('defaultCurrency', value),
                ),
              ],
            ),
            _SettingsSection(
              title: 'Notifications',
              children: [
                _SwitchSetting(
                    label: 'Email',
                    value: _bool('emailNotifications'),
                    onChanged: (value) => _save('emailNotifications', value)),
                _SwitchSetting(
                    label: 'SMS',
                    value: _bool('smsNotifications'),
                    onChanged: (value) => _save('smsNotifications', value)),
                _SwitchSetting(
                    label: 'Push',
                    value: _bool('pushNotifications'),
                    onChanged: (value) => _save('pushNotifications', value)),
                _SwitchSetting(
                    label: 'Admin alerts',
                    value: _bool('adminAlerts'),
                    onChanged: (value) => _save('adminAlerts', value)),
              ],
            ),
            _SettingsSection(
              title: 'Security',
              children: [
                _NumberSetting(
                  label: 'Admin session timeout',
                  suffix: 'minutes',
                  value: _int('adminSessionTimeoutMinutes'),
                  onChanged: (value) =>
                      _save('adminSessionTimeoutMinutes', value),
                ),
                _SwitchSetting(
                    label: 'Require MFA',
                    value: _bool('requireMfa'),
                    onChanged: (value) => _save('requireMfa', value)),
                _TextSetting(
                    label: 'Password policy',
                    value: _string('passwordPolicy'),
                    onChanged: (value) => _save('passwordPolicy', value)),
                _SwitchSetting(
                    label: 'Audit logging',
                    value: _bool('auditLogging'),
                    onChanged: (value) => _save('auditLogging', value)),
              ],
            ),
            _SettingsSection(
              title: 'Intelligence',
              children: [
                _SwitchSetting(
                    label: 'IRIS enabled',
                    value: _bool('irisEnabled'),
                    onChanged: (value) => _save('irisEnabled', value)),
                _SwitchSetting(
                    label: 'Automatic anomaly detection',
                    value: _bool('automaticAnomalyDetection'),
                    onChanged: (value) =>
                        _save('automaticAnomalyDetection', value)),
                _SwitchSetting(
                    label: 'Occupancy prediction',
                    value: _bool('occupancyPrediction'),
                    onChanged: (value) => _save('occupancyPrediction', value)),
                _SwitchSetting(
                    label: 'Fraud detection',
                    value: _bool('fraudDetection'),
                    onChanged: (value) => _save('fraudDetection', value)),
              ],
            ),
            _SettingsSection(
              title: 'Integrations',
              children: [
                _TextSetting(
                    label: 'Firebase status',
                    value: _string('firebaseStatus'),
                    onChanged: (value) => _save('firebaseStatus', value)),
                _TextSetting(
                    label: 'Stripe status',
                    value: _string('stripeStatus'),
                    onChanged: (value) => _save('stripeStatus', value)),
                _TextSetting(
                    label: 'Google Maps status',
                    value: _string('googleMapsStatus'),
                    onChanged: (value) => _save('googleMapsStatus', value)),
                _TextSetting(
                    label: 'Email provider status',
                    value: _string('emailProviderStatus'),
                    onChanged: (value) => _save('emailProviderStatus', value)),
              ],
            ),
          ],
        );
      },
    );
  }

  int _int(String key) => (_data[key] as num?)?.toInt() ?? 0;
  bool _bool(String key) => _data[key] == true;
  String _string(String key) => _data[key]?.toString() ?? '';
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(22),
      decoration: adminGlassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: adminHeading(size: 30)),
          const SizedBox(height: 16),
          Wrap(spacing: 14, runSpacing: 14, children: children),
        ],
      ),
    );
  }
}

class _TextSetting extends StatefulWidget {
  const _TextSetting({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_TextSetting> createState() => _TextSettingState();
}

class _TextSettingState extends State<_TextSetting> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: widget.onChanged,
        onEditingComplete: () => widget.onChanged(_controller.text),
      ),
    );
  }
}

class _NumberSetting extends StatelessWidget {
  const _NumberSetting({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.suffix,
  });

  final String label;
  final int value;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: TextFormField(
        initialValue: '$value',
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, suffixText: suffix),
        onFieldSubmitted: (value) => onChanged(int.tryParse(value) ?? 0),
        onEditingComplete: () {},
      ),
    );
  }
}

class _SwitchSetting extends StatelessWidget {
  const _SwitchSetting({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Text(label),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

String _dateLabel(Object? value) {
  if (value is Timestamp) return value.toDate().toLocal().toString();
  return 'Not saved yet';
}
