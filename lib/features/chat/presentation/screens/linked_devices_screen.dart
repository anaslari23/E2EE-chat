import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/providers.dart';

class LinkedDevicesScreen extends ConsumerStatefulWidget {
  const LinkedDevicesScreen({super.key});

  @override
  ConsumerState<LinkedDevicesScreen> createState() => _LinkedDevicesScreenState();
}

class _LinkedDevicesScreenState extends ConsumerState<LinkedDevicesScreen> {
  // Placeholder for simulating a secondary device
  String? _simulatedCode;

  void _simulateNewDevice() async {
    final api = ref.read(apiServiceProvider);
    final signal = ref.read(signalServiceProvider);

    // 1. Generate Ephemeral Key (new device side)
    final keyPair = await signal.generateProvisioningKeyPair();
    // 2. Request Code
    try {
      final code = await api.requestDeviceLinking('placeholder_public_key'); // In real app, serialize `keyPair.publicKey`
      setState(() {
        _simulatedCode = code;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _approveLink() async {
    if (_simulatedCode == null) return;
    
    // Primary Device Flow
    final api = ref.read(apiServiceProvider);
    final signal = ref.read(signalServiceProvider);
    
    try {
      // 1. Get Status (simulate scanning)
      final status = await api.getLinkingStatus(_simulatedCode!);
      final remoteKeyStr = status['ephemeral_public_key'];
      // final remoteKey = ... decode remoteKeyStr
      
      // 2. Encrypt Secrets
      final secrets = await signal.exportIdentitySecrets();
      // final encrypted = await signal.encryptProvisioningData(remoteKey, secrets); 
      // Simplified for MVP:
      final encryptedStr = "encrypted_blob"; 

      // 3. Approve
      final token = "get_token_from_auth_provider"; // simplified
      // await api.approveDeviceLinking(_simulatedCode!, encryptedStr, token);
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device Linked!')));
      setState(() => _simulatedCode = null);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Linked Devices')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDeviceItem('Chrome (Mac)', 'Online', true),
          _buildDeviceItem('iPad', 'Last active today at 10:30 AM', false),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
               // Open Scanner (Real implementation)
               // context.push('/scan-qr');
               _simulateNewDevice(); // Simulation for this environment
            },
            icon: const Icon(Icons.add),
            label: const Text('Link a Device'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          if (_simulatedCode != null) ...[
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  const Text("Use Camera to scan this QR code on the new device (Simulated):"),
                  const SizedBox(height: 10),
                  QrImageView(
                    data: _simulatedCode!,
                    version: QrVersions.auto,
                    size: 200.0,
                  ),
                  const SizedBox(height: 10),
                  Text("Code: $_simulatedCode", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _approveLink, 
                    child: const Text("Simulate Scanning & Approval (On Primary)")
                  )
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildDeviceItem(String name, String status, bool isActive) {
    return ListTile(
      leading: Icon(Icons.laptop_mac, color: isActive ? Colors.green : Colors.grey),
      title: Text(name),
      subtitle: Text(status),
      trailing: IconButton(
        icon: const Icon(Icons.logout),
        onPressed: () {}, // Unlink
      ),
    );
  }
}
