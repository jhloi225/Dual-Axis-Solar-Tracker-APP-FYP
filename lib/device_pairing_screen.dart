import 'package:flutter/material.dart';
import 'firebase_auth_service.dart';

class DevicePairingScreen extends StatefulWidget {
  const DevicePairingScreen({super.key});

  @override
  State<DevicePairingScreen> createState() => _DevicePairingScreenState();
}

class _DevicePairingScreenState extends State<DevicePairingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _deviceIdController = TextEditingController();
  final _pinController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  Future<void> _pairDevice() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final isPaired = await _authService.pairDevice(
        deviceId: _deviceIdController.text,
        pin: _pinController.text,
      );

      setState(() {
        _isLoading = false;
      });

      if (isPaired) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pairing failed. Check the device ID and PIN.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pair New Device', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                const Text(
                'Enter the ID and PIN from your device.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _deviceIdController,
                decoration: const InputDecoration(labelText: 'Device ID', prefixIcon: Icon(Icons.perm_identity)),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the device ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pinController,
                decoration: const InputDecoration(labelText: 'Device PIN', prefixIcon: Icon(Icons.pin)),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the 6-digit PIN';
                  }
                  if (value.length != 6) {
                    return 'The PIN must be 6 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _pairDevice,
                child: _isLoading
                    ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                    : const Text('Pair Device'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
