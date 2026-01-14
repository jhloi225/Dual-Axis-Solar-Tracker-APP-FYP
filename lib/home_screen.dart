import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import './firebase_auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription<DatabaseEvent>? _deviceStatusSubscription;
  Map<String, dynamic>? _deviceData;
  String _deviceName = 'Solar Tracker';
  bool _isCheckingDevice = true;
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    _activateDeviceListener();
  }

  void _activateDeviceListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _getDeviceId(user.uid).then((deviceId) {
      if (mounted) {
        setState(() {
          _deviceId = deviceId;
          _isCheckingDevice = false;
        });
      }

      if (deviceId != null) {
        _fetchDeviceName(deviceId);
        final dbRef = FirebaseDatabase.instance.ref('devices/$deviceId/status');
        _deviceStatusSubscription = dbRef.onValue.listen((event) {
          if (mounted && event.snapshot.value != null) {
            setState(() {
              _deviceData = Map<String, dynamic>.from(event.snapshot.value as Map);
            });
          }
        });
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

  @override
  void dispose() {
    _deviceStatusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_deviceId == null ? 'SolarTrack Pro' : _deviceName, 
          style: const TextStyle(fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: false,
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
    if (_isCheckingDevice) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_deviceId == null) {
      return _buildNoDeviceUI();
    }

    if (_deviceData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      children: <Widget>[
        const SizedBox(height: 16),
        _buildPowerCard(),
        const SizedBox(height: 24),
        _buildMetricsGrid(),
        const SizedBox(height: 24),
        const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildActionCard(
          icon: Icons.videocam_outlined,
          title: 'Live Camera',
          subtitle: 'Check panel cleanliness and surroundings',
          onTap: () => Navigator.pushNamed(context, '/live_camera'),
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          icon: Icons.settings_remote,
          title: 'Manual Control',
          subtitle: 'Adjust panel position for maintenance',
          onTap: () => Navigator.pushNamed(context, '/manual_control'),
        ),
        const SizedBox(height: 20),
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
            const Text('No Device Connected', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
              'Please pair your solar tracker to see live data.', 
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

  Widget _buildPowerCard() {
    final primaryColor = Theme.of(context).primaryColor;
    final currentPower = double.tryParse(_deviceData!['power_output']?.toString() ?? '0.0') ?? 0.0;
    final currentMode = _deviceData!['mode'] ?? 'auto';
    final isTracking = currentMode == 'auto';
    final isProtected = currentMode == 'wind_protect' || currentMode == 'emergency_stop';

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Current Power Output', style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 8),
            Text(
              '${currentPower.toStringAsFixed(2)} Watts',
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: primaryColor),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  isProtected ? Icons.warning_amber_rounded : (isTracking ? Icons.wb_sunny_rounded : Icons.pan_tool_rounded),
                  color: isProtected ? Colors.redAccent : (isTracking ? Colors.orangeAccent : Colors.blueGrey),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  isProtected ? 'Protected Mode ($currentMode)' : (isTracking ? 'Auto-Tracking Sun' : 'Manual/Stationary'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    final batteryLevel = _deviceData!['battery_level'] ?? 0;
    final batteryVoltage = double.tryParse(_deviceData!['battery_voltage']?.toString() ?? '0.0') ?? 0.0;
    final windSpeed = _deviceData!['wind_speed'] ?? '0.0';
    final horizontalAngle = _deviceData!['horizontal_angle'] ?? 0;
    final verticalAngle = _deviceData!['vertical_angle'] ?? 0;
    final generatedToday = double.tryParse(_deviceData!['generated_today']?.toString() ?? '0.0') ?? 0.0;

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.85,
      children: [
        _buildMetricCard(icon: Icons.rotate_90_degrees_cw_rounded, label: 'H. Angle', value: '$horizontalAngle°'),
        _buildMetricCard(icon: Icons.rotate_left_rounded, label: 'V. Angle', value: '$verticalAngle°'),
        _buildMetricCard(icon: Icons.air_rounded, label: 'Wind', value: '$windSpeed m/s'),
        _buildMetricCard(
          icon: Icons.battery_charging_full_rounded,
          label: 'Battery',
          value: '$batteryLevel%',
          valueColor: batteryLevel > 20 ? Colors.green : Colors.red,
        ),
        _buildMetricCard(
          icon: Icons.flash_on_rounded,
          label: 'Today',
          value: '${generatedToday.toStringAsFixed(1)} Wh',
        ),
        _buildMetricCard(icon: Icons.power, label: 'Voltage', value: '${batteryVoltage.toStringAsFixed(2)} V'),
      ],
    );
  }

  Widget _buildMetricCard({required IconData icon, required String label, required String value, Color? valueColor}) {
    final color = valueColor ?? Theme.of(context).textTheme.bodyLarge!.color;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Text(label, 
              style: const TextStyle(color: Colors.grey, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        leading: Icon(icon, size: 36, color: Theme.of(context).primaryColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
