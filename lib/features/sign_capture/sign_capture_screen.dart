import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import 'sign_capture_service.dart';

// If geolocator web support requires web/index.html permission policy setup,
// apply it manually later. Do not edit web/index.html in this task.

class SignCaptureScreen extends StatefulWidget {
  const SignCaptureScreen({super.key});

  @override
  State<SignCaptureScreen> createState() => _SignCaptureScreenState();
}

class _SignCaptureScreenState extends State<SignCaptureScreen> {
  final _service = SignCaptureService();
  final _picker = ImagePicker();
  final _streetController = TextEditingController();
  final _boroughController = TextEditingController();
  final _councilController = TextEditingController();
  final _postcodeController = TextEditingController();
  final _activeHoursController = TextEditingController();
  final _maxStayController = TextEditingController();
  final _notesController = TextEditingController();

  SignCaptureOutcome? _locationOutcome;
  XFile? _photo;
  bool? _parkingAllowed;
  bool? _loadingAllowed;
  bool? _permitRequired;
  bool _redRoute = false;
  bool _busLane = false;
  bool _schoolStreet = false;
  bool _loadingLocation = true;
  bool _submitting = false;
  final Set<String> _activeDays = {};

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  @override
  void dispose() {
    _streetController.dispose();
    _boroughController.dispose();
    _councilController.dispose();
    _postcodeController.dispose();
    _activeHoursController.dispose();
    _maxStayController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    setState(() {
      _loadingLocation = true;
      _locationOutcome = null;
    });

    final outcome = await _service.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _locationOutcome = outcome;
      _loadingLocation = false;
    });
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _photo = picked);
  }

  Future<void> _submit() async {
    final location = _locationOutcome;
    if (!_canSubmit || location == null) return;

    setState(() => _submitting = true);
    final success = await _service.submit(
      photo: _photo!,
      latitude: location.latitude!,
      longitude: location.longitude!,
      gpsAccuracyMeters: location.gpsAccuracyMeters!,
      gpsCapturedAt: location.gpsCapturedAt!,
      streetName: _streetController.text,
      borough: _boroughController.text,
      council: _councilController.text,
      postcode: _postcodeController.text,
      activeHours: _emptyToNull(_activeHoursController.text),
      activeDays: _activeDays.toList(growable: false),
      maxStayMinutes: int.tryParse(_maxStayController.text.trim()),
      parkingAllowed: _parkingAllowed,
      loadingAllowed: _loadingAllowed,
      permitRequired: _permitRequired,
      redRoute: _redRoute,
      busLane: _busLane,
      schoolStreet: _schoolStreet,
      notes: _emptyToNull(_notesController.text),
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Sign submitted for review'
              : 'Could not submit sign. Please try again.',
        ),
      ),
    );

    if (success) {
      Navigator.of(context).pop();
    }
  }

  bool get _hasRequiredText {
    return _streetController.text.trim().isNotEmpty &&
        _boroughController.text.trim().isNotEmpty &&
        _councilController.text.trim().isNotEmpty &&
        _postcodeController.text.trim().isNotEmpty;
  }

  bool get _gpsFresh {
    final capturedAt = _locationOutcome?.gpsCapturedAt;
    if (capturedAt == null) return false;
    return DateTime.now().difference(capturedAt).abs() <=
        SignCaptureService.maxGpsAge;
  }

  bool get _gpsAccurate {
    final accuracy = _locationOutcome?.gpsAccuracyMeters;
    if (accuracy == null) return false;
    return accuracy <= SignCaptureService.maxGpsAccuracyMeters;
  }

  bool get _canSubmit {
    return !_submitting &&
        _photo != null &&
        (_locationOutcome?.isSuccess ?? false) &&
        _gpsAccurate &&
        _gpsFresh &&
        _hasRequiredText;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report a sign')),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loadingLocation) {
      return const Center(child: Text('Getting your location…'));
    }

    final location = _locationOutcome;
    if (location == null || !location.isSuccess) {
      return _LocationFailureView(
        reason: location?.failureReason,
        onRetry: _loadLocation,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Location: ${location.latitude!.toStringAsFixed(4)}, '
          '${location.longitude!.toStringAsFixed(4)}',
        ),
        Text('Accuracy: ${location.gpsAccuracyMeters!.round()} m'),
        if (!_gpsAccurate) ...[
          const SizedBox(height: 8),
          const Text(
            'Please move closer to the sign and try again for a more accurate GPS location.',
          ),
        ],
        if (!_gpsFresh) ...[
          const SizedBox(height: 8),
          const Text(
              'Location fix is too old. Retry location before submitting.'),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _loadLocation,
          icon: const Icon(Icons.my_location),
          label: const Text('Retry location'),
        ),
        const SizedBox(height: 20),
        _PhotoPicker(
          photo: _photo,
          onCamera: () => _pickPhoto(ImageSource.camera),
          onGallery: () => _pickPhoto(ImageSource.gallery),
        ),
        const SizedBox(height: 20),
        _requiredTextField(_streetController, 'Street name'),
        _requiredTextField(_boroughController, 'Borough'),
        _requiredTextField(_councilController, 'Council'),
        _requiredTextField(_postcodeController, 'Postcode'),
        TextField(
          controller: _activeHoursController,
          decoration: const InputDecoration(labelText: 'Active hours'),
        ),
        TextField(
          controller: _maxStayController,
          decoration: const InputDecoration(labelText: 'Max stay minutes'),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        TextField(
          controller: _notesController,
          decoration: const InputDecoration(labelText: 'Notes'),
          minLines: 2,
          maxLines: 4,
        ),
        const SizedBox(height: 20),
        const Text('Active days'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final day in _days)
              FilterChip(
                label: Text(day),
                selected: _activeDays.contains(day),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _activeDays.add(day);
                    } else {
                      _activeDays.remove(day);
                    }
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 20),
        _threeStateDropdown(
          label: 'Parking allowed',
          value: _parkingAllowed,
          onChanged: (value) => setState(() => _parkingAllowed = value),
        ),
        _threeStateDropdown(
          label: 'Loading allowed',
          value: _loadingAllowed,
          onChanged: (value) => setState(() => _loadingAllowed = value),
        ),
        _threeStateDropdown(
          label: 'Permit required',
          value: _permitRequired,
          onChanged: (value) => setState(() => _permitRequired = value),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Red route'),
          value: _redRoute,
          onChanged: (value) => setState(() => _redRoute = value ?? false),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Bus lane'),
          value: _busLane,
          onChanged: (value) => setState(() => _busLane = value ?? false),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('School street'),
          value: _schoolStreet,
          onChanged: (value) => setState(() => _schoolStreet = value ?? false),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: Text(_submitting ? 'Submitting…' : 'Submit sign'),
        ),
      ],
    );
  }

  Widget _requiredTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _threeStateDropdown({
    required String label,
    required bool? value,
    required ValueChanged<bool?> onChanged,
  }) {
    return DropdownButtonFormField<bool?>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: const [
        DropdownMenuItem<bool?>(value: null, child: Text('Unknown')),
        DropdownMenuItem<bool?>(value: true, child: Text('Yes')),
        DropdownMenuItem<bool?>(value: false, child: Text('No')),
      ],
      onChanged: onChanged,
    );
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _LocationFailureView extends StatelessWidget {
  const _LocationFailureView({
    required this.reason,
    required this.onRetry,
  });

  final SignCaptureFailureReason? reason;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final serviceDisabled = reason == SignCaptureFailureReason.serviceDisabled;
    final deniedForever =
        reason == SignCaptureFailureReason.permissionDeniedForever;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              serviceDisabled
                  ? 'Enable location services to submit this sign.'
                  : 'ParkPal requires location access to verify where parking signs are located.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (deniedForever)
              FilledButton(
                onPressed: Geolocator.openAppSettings,
                child: const Text('Open app settings'),
              )
            else
              FilledButton(
                onPressed: onRetry,
                child: const Text('Retry location'),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.photo,
    required this.onCamera,
    required this.onGallery,
  });

  final XFile? photo;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sign photo'),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton.icon(
              onPressed: onCamera,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Camera'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: onGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Gallery'),
            ),
          ],
        ),
        if (photo != null) ...[
          const SizedBox(height: 12),
          FutureBuilder(
            future: photo!.readAsBytes(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  snapshot.data!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
