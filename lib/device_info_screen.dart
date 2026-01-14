import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import './firebase_auth_service.dart';

class DeviceInfoScreen extends StatefulWidget {
  const DeviceInfoScreen({super.key});

  @override
  State<DeviceInfoScreen> createState() => _DeviceInfoScreenState();
}

class _DeviceInfoScreenState extends State<DeviceInfoScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _nameController = TextEditingController();
  StreamSubscription<DatabaseEvent>? _statusSubscription;
  Timer? _statusTimer;
  String? _deviceId;
  String _deviceName = 'Solar Tracker';
  bool _hasPairedDevice = false;
  bool _isLoading = true;
  Map<String, dynamic> _deviceData = {};

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _statusSubscription?.cancel();
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final deviceId = await _getDeviceId(user.uid);
    if (deviceId != null) {
      if (!mounted) return;
      setState(() {
        _deviceId = deviceId;
        _hasPairedDevice = true;
      });
      _fetchDeviceName(deviceId);
      _activateStatusListener(deviceId);
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _activateStatusListener(String deviceId) {
    final statusRef = FirebaseDatabase.instance.ref('devices/$deviceId/status');
    _statusSubscription = statusRef.onValue.listen((event) {
      if (mounted && event.snapshot.exists && event.snapshot.value is Map) {
        setState(() {
          _deviceData = Map<String, dynamic>.from(event.snapshot.value as Map);
        });
      }
    });

    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (timer) { 
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _fetchDeviceName(String deviceId) async {
    final nameSnapshot = await FirebaseDatabase.instance.ref('devices/$deviceId/settings/name').get();
    if (mounted && nameSnapshot.exists && nameSnapshot.value != null) {
      setState(() {
        _deviceName = nameSnapshot.value.toString();
      });
    }
  }

  Future<String?> _getDeviceId(String uid) async {
    final snapshot = await FirebaseDatabase.instance.ref('users/$uid/owned_devices').get();
    if (snapshot.exists && snapshot.value != null) {
      return (snapshot.value as Map).keys.first;
    }
    return null;
  }

  Future<void> _showRenameDialog() async {
    _nameController.text = _deviceName;
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Rename Device', style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter a new name'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final newName = _nameController.text;
                if (newName.isNotEmpty) {
                  await FirebaseDatabase.instance.ref('devices/$_deviceId/settings/name').set(newName);
                  if (mounted) {
                    setState(() => _deviceName = newName);
                    Navigator.of(context).pop();
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleDisconnect() async {
    if (_deviceId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Device?'),
        content: const Text('This will remove the link between your account and this tracker. You will need to pair it again to control it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep Connected')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Disconnect', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final success = await _authService.disconnectDevice(_deviceId!);
      if (mounted) {
        if (success) {
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to disconnect. Please try again.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Device', style: TextStyle(fontWeight: FontWeight.bold)),
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

    if (!_hasPairedDevice) {
      return _buildNoDeviceUI();
    }

    final lastSeenRaw = _deviceData['last_seen'];
    final firmwareVersion = _deviceData['firmware'] as String? ?? 'N/A';
    bool isOnline = false;

    if (lastSeenRaw is num) {
        final lastSeenDateTime = DateTime.fromMillisecondsSinceEpoch(lastSeenRaw.toInt() * 1000, isUtc: true);
        final diffInSeconds = DateTime.now().toUtc().difference(lastSeenDateTime).inSeconds.abs();
        isOnline = diffInSeconds < 10;
    }
    
    final statusColor = isOnline ? Colors.green : Colors.red;
    final statusText = isOnline ? 'Online' : 'Offline';

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: <Widget>[
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.solar_power_rounded, color: Theme.of(context).primaryColor, size: 48),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_deviceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.circle, color: statusColor, size: 12),
                          const SizedBox(width: 6),
                          Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                  onPressed: _showRenameDialog,
                  tooltip: 'Rename Device',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Device Information'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                InfoRow(label: 'Device ID', value: _deviceId ?? 'N/A'),
                const Divider(height: 24),
                const InfoRow(label: 'Model', value: 'SolarTrack Pro v1.0'),
                const Divider(height: 24),
                InfoRow(label: 'Firmware', value: firmwareVersion),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
        OutlinedButton.icon(
          onPressed: _handleDisconnect,
          icon: const Icon(Icons.link_off, color: Colors.red),
          label: const Text('Disconnect Device', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              'To view technical details, please pair a tracker to your account.', 
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const InfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}
