import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LiveCameraScreen extends StatefulWidget {
  const LiveCameraScreen({super.key});

  @override
  State<LiveCameraScreen> createState() => _LiveCameraScreenState();
}

class _LiveCameraScreenState extends State<LiveCameraScreen> {
  String? _deviceId;
  DatabaseReference? _statusRef;
  StreamSubscription<DatabaseEvent>? _statusSubscription;
  Map<String, dynamic> _deviceData = {};
  bool _isCapturing = false;

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
          _isCapturing = _deviceData['capture_photo'] == true;
        });
      }
    });
  }

  Future<void> _triggerCapture() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);
    await _statusRef?.child('capture_photo').set(true);
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _deviceData['image_url'] as String?;
    final lastCaptureTime = _deviceData['timestamp'] as num?;
    final dustLevel = _deviceData['dust_level'] as num? ?? 0;
    
    String formattedTime = 'Never';
    if (lastCaptureTime != null) {
        final dateTime = DateTime.fromMillisecondsSinceEpoch(lastCaptureTime.toInt() * 1000);
        formattedTime = DateFormat.yMd().add_Hms().format(dateTime);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Camera & Dust'),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black87,
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(child: Icon(Icons.error_outline, color: Colors.red, size: 50));
                      },
                    )
                  : const Center(
                      child: Text('No image available. Tap refresh to capture.', style: TextStyle(color: Colors.white)),
                    ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ListTile(
                    title: const Text('Last Update'),
                    trailing: Text(formattedTime, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  ListTile(
                    title: const Text('Dust Level'),
                    trailing: Text('${dustLevel.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).primaryColor)),
                  ),
                  ElevatedButton.icon(
                    onPressed: _triggerCapture,
                    icon: _isCapturing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.camera_alt),
                    label: Text(_isCapturing ? 'Processing...' : 'Capture New Image'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
