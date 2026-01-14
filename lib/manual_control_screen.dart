import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class ManualControlScreen extends StatefulWidget {
  const ManualControlScreen({super.key});

  @override
  State<ManualControlScreen> createState() => _ManualControlScreenState();
}

class _ManualControlScreenState extends State<ManualControlScreen> {
  String? _deviceId;
  DatabaseReference? _controlRef;
  DatabaseReference? _statusRef;
  StreamSubscription<DatabaseEvent>? _statusSubscription;
  Map<String, dynamic> _deviceData = {};
  final TextEditingController _angleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final deviceId = await _getDeviceId(user.uid);
    if (deviceId != null) {
      setState(() {
        _deviceId = deviceId;
        _controlRef = FirebaseDatabase.instance.ref('devices/$deviceId/control');
        _statusRef = FirebaseDatabase.instance.ref('devices/$deviceId/status');
      });
      _activateStatusListener();
    }
  }

  Future<String?> _getDeviceId(String uid) async {
    final snapshot = await FirebaseDatabase.instance.ref('users/$uid/owned_devices').get();
    if (snapshot.exists && snapshot.value != null) {
      return (snapshot.value as Map).keys.first;
    }
    return null;
  }

  void _activateStatusListener() {
    _statusSubscription = _statusRef?.onValue.listen((event) {
      if (mounted && event.snapshot.value != null) {
        setState(() {
          _deviceData = Map<String, dynamic>.from(event.snapshot.value as Map);
        });
      }
    });
  }

  void _sendCommand(String command) {
    _controlRef?.child('command').set(command);
  }

  Future<void> _showSetAngleDialog(bool isVertical) async {
    _angleController.clear();
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Set ${isVertical ? "Vertical" : "Horizontal"} Angle', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: _angleController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter degrees (0-180)'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final String angle = _angleController.text;
                final String command = isVertical ? "set_v:$angle" : "set_h:$angle";
                _sendCommand(command);
                Navigator.of(context).pop();
              },
              child: const Text('Go'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _angleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_deviceId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Manual Control'),
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
        body: Center(
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
                  'Please pair a tracker to enable manual control.', 
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
        ),
      );
    }

    int hPos = _deviceData['horizontal_angle'] ?? 90;
    int vPos = _deviceData['vertical_angle'] ?? 90;
    String currentMode = _deviceData['mode'] ?? 'auto';
    bool isManual = currentMode == 'manual';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Control', style: TextStyle(fontWeight: FontWeight.bold)),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
             _buildSectionTitle('Tracking Mode'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(child: ModeToggleButton(label: 'Auto', mode: 'auto', currentMode: currentMode, onSelect: _sendCommand)),
                    Expanded(child: ModeToggleButton(label: 'Manual', mode: 'manual', currentMode: currentMode, onSelect: _sendCommand)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Current Panel Position'),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    AngleControl(label: 'Horizontal', angle: hPos, onTap: () => _showSetAngleDialog(false)),
                    AngleControl(label: 'Vertical', angle: vPos, onTap: () => _showSetAngleDialog(true)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Manual Adjustments'),
             Card(
              color: isManual ? Colors.white : Theme.of(context).scaffoldBackgroundColor,
              child: DirectionalPad(
                isEnabled: isManual,
                currentH: hPos,
                currentV: vPos,
                onSetAngle: (cmd) => _sendCommand(cmd),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _sendCommand('emergency_stop'),
              icon: const Icon(Icons.warning, color: Colors.white),
              label: const Text('EMERGENCY STOP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 18),
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

class AngleControl extends StatelessWidget {
  final String label;
  final int angle;
  final VoidCallback onTap;

  const AngleControl({super.key, required this.label, required this.angle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('$angle°', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                const SizedBox(width: 8),
                const Icon(Icons.edit, color: Colors.grey, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ModeToggleButton extends StatelessWidget {
  final String label, mode, currentMode;
  final Function(String) onSelect;

  const ModeToggleButton({super.key, required this.label, required this.mode, required this.currentMode, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    bool isActive = currentMode == mode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ElevatedButton(
        onPressed: () => onSelect(mode),
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive ? Theme.of(context).primaryColor : Colors.white,
          foregroundColor: isActive ? Colors.white : Colors.black87,
          elevation: isActive ? 2 : 0,
          side: isActive ? BorderSide.none : BorderSide(color: Colors.grey[300]!),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class DirectionalPad extends StatelessWidget {
  final bool isEnabled;
  final int currentH;
  final int currentV;
  final Function(String) onSetAngle;

  const DirectionalPad({
    super.key, 
    required this.isEnabled, 
    required this.currentH, 
    required this.currentV,
    required this.onSetAngle
  });

  Widget _buildButton(IconData icon, String type, int delta, BuildContext context) {
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.4,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ElevatedButton(
          onPressed: isEnabled ? () {
            if (type == 'v') {
              int target = (currentV + delta).clamp(0, 180);
              onSetAngle('set_v:$target');
            } else {
              int target = (currentH + delta).clamp(0, 180);
              onSetAngle('set_h:$target');
            }
          } : null,
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(16),
            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
            foregroundColor: Theme.of(context).primaryColor,
            elevation: 0,
          ),
          child: Icon(icon, size: 32),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildButton(Icons.arrow_upward, 'v', 10, context),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildButton(Icons.arrow_back, 'h', 10, context),
              const SizedBox(width: 80, height: 80), // Spacer
              _buildButton(Icons.arrow_forward, 'h', -10, context),
            ],
          ),
        ),
        _buildButton(Icons.arrow_downward, 'v', -10, context),
      ],
    );
  }
}
