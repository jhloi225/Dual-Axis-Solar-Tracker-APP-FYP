import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _deviceId;
  bool _isLoading = true;

  bool _stormProtectionEnabled = true;
  double _windProtectionThreshold = 15.0;
  double _highWindAlertThreshold = 10.0;
  double _dustAlertThreshold = 30.0;
  bool _stormAlertsEnabled = true;
  bool _dustAlertsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadInitialSettings();
  }

  Future<void> _loadInitialSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final deviceId = await _getDeviceId(user.uid);
    if (deviceId == null) {
      setState(() => _isLoading = false);
      return;
    }
    _deviceId = deviceId;

    final settingsRef = FirebaseDatabase.instance.ref('devices/$deviceId/settings');
    final snapshot = await settingsRef.get();

    if (mounted && snapshot.exists && snapshot.value != null) {
      final settings = snapshot.value as Map<dynamic, dynamic>;
      setState(() {
        _stormProtectionEnabled = settings['storm_protection_enabled'] as bool? ?? true;
        _windProtectionThreshold = double.tryParse(settings['wind_protection_threshold']?.toString() ?? '15.0') ?? 15.0;
        _highWindAlertThreshold = double.tryParse(settings['high_wind_alert_threshold']?.toString() ?? '10.0') ?? 10.0;
        _dustAlertThreshold = double.tryParse(settings['dust_alert_threshold']?.toString() ?? '30.0') ?? 30.0;
        _stormAlertsEnabled = settings['storm_alerts_on'] as bool? ?? true;
        _dustAlertsEnabled = settings['dust_alerts_enabled'] as bool? ?? true;
      });
    }
    setState(() => _isLoading = false);
  }

  Future<String?> _getDeviceId(String uid) async {
    final snapshot = await FirebaseDatabase.instance.ref('users/$uid/owned_devices').get();
    if (snapshot.exists && snapshot.value != null) {
      return (snapshot.value as Map).keys.first;
    }
    return null;
  }

  Future<void> _updateFirebaseSetting(String key, dynamic value) async {
    if (_deviceId != null) {
      await FirebaseDatabase.instance.ref('devices/$_deviceId/settings/$key').set(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, size: 28),
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, size: 28),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_deviceId == null) {
      return _buildNoDeviceUI();
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: <Widget>[
        _buildSectionTitle('Protection & Safety'),
        NotificationSwitchTile(
          title: 'Storm Protection',
          subtitle: 'Move to 120° safe angle in high winds',
          value: _stormProtectionEnabled,
          onChanged: (v) {
            setState(() => _stormProtectionEnabled = v);
            _updateFirebaseSetting('storm_protection_enabled', v);
          },
        ),
        SettingCard(
          title: 'Wind Protection Limit',
          subtitle: 'Activate protection at ${_windProtectionThreshold.toStringAsFixed(1)} m/s',
          child: Slider(
            value: _windProtectionThreshold,
            min: 5.0, max: 30.0, divisions: 50,
            label: _windProtectionThreshold.toStringAsFixed(1),
            onChanged: (v) => setState(() => _windProtectionThreshold = v),
            onChangeEnd: (v) => _updateFirebaseSetting('wind_protection_threshold', v),
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('Alert Notifications'),
        NotificationSwitchTile(
          title: 'Wind Speed Alerts',
          subtitle: 'Notify when wind reaches threshold',
          value: _stormAlertsEnabled,
          onChanged: (v) {
            setState(() => _stormAlertsEnabled = v);
            _updateFirebaseSetting('storm_alerts_on', v);
          },
        ),
        SettingCard(
          title: 'Alert Trigger Speed',
          subtitle: 'Send notification at ${_highWindAlertThreshold.toStringAsFixed(1)} m/s',
          child: Slider(
            value: _highWindAlertThreshold,
            min: 2.0, max: 20.0, divisions: 36,
            label: _highWindAlertThreshold.toStringAsFixed(1),
            onChanged: (v) => setState(() => _highWindAlertThreshold = v),
            onChangeEnd: (v) => _updateFirebaseSetting('high_wind_alert_threshold', v),
          ),
        ),
        const Divider(height: 32),
        NotificationSwitchTile(
          title: 'Dust Level Alerts',
          subtitle: 'Notify when panels need cleaning',
          value: _dustAlertsEnabled,
          onChanged: (v) {
            setState(() => _dustAlertsEnabled = v);
            _updateFirebaseSetting('dust_alerts_enabled', v);
          },
        ),
        SettingCard(
          title: 'Dust Alert Threshold',
          subtitle: 'Notify at ${_dustAlertThreshold.toStringAsFixed(0)}% accumulation',
          child: Slider(
            value: _dustAlertThreshold,
            min: 5.0, max: 95.0, divisions: 18,
            label: _dustAlertThreshold.toStringAsFixed(0),
            onChanged: (v) => setState(() => _dustAlertThreshold = v),
            onChangeEnd: (v) => _updateFirebaseSetting('dust_alert_threshold', v),
          ),
        ),
      ],
    );
  }

  Widget _buildNoDeviceUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.link_off_rounded, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            const Text('No Device Paired', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
              'Please pair a tracker to configure alerts and protection settings.', 
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/pair_device'),
              icon: const Icon(Icons.add),
              label: const Text('Pair Now'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {Color color = Colors.black87}) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      );
  }
}

class SettingCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const SettingCard({super.key, required this.title, required this.subtitle, required this.child});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(subtitle, style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 14)),
            child,
          ],
        ),
      ),
    );
  }
}

class NotificationSwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const NotificationSwitchTile({super.key, required this.title, required this.subtitle, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
        value: value,
        onChanged: onChanged,
        activeColor: Theme.of(context).primaryColor,
      ),
    );
  }
}
