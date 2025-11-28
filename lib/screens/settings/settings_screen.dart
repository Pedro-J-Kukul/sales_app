// File: lib/screens/settings/settings_screen.dart

import 'package:flutter/material.dart';
import '../../utils/preferences.dart';
import '../../utils/network_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ipController = TextEditingController();
  final portController = TextEditingController();
  bool isLoading = false;
  bool isTesting = false;
  String? errorMessage;
  String? successMessage;
  String? connectionStatus;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    ipController.dispose();
    portController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => isLoading = true);
    final ip = await AppPreferences.getIpAddress();
    final port = await AppPreferences.getPort();
    setState(() {
      ipController.text = ip;
      portController.text = port;
      isLoading = false;
    });
  }

  Future<void> _testConnection() async {
    setState(() {
      isTesting = true;
      errorMessage = null;
      successMessage = null;
      connectionStatus = null;
    });

    final ip = ipController.text.trim();
    final port = portController.text.trim();

    // Validate inputs
    if (!NetworkHelper.isValidIpAddress(ip)) {
      setState(() {
        isTesting = false;
        errorMessage = 'Invalid IP address format';
      });
      return;
    }

    if (!NetworkHelper.isValidPort(port)) {
      setState(() {
        isTesting = false;
        errorMessage = 'Invalid port number (1-65535)';
      });
      return;
    }

    // Test connection
    final portNum = int.parse(port);
    final connected = await NetworkHelper.testConnection(ip, portNum);

    setState(() {
      isTesting = false;
      if (connected) {
        connectionStatus = 'Connected successfully!';
        successMessage = 'Connection test passed';
      } else {
        connectionStatus = 'Connection failed';
        errorMessage = 'Could not connect to $ip:$port';
      }
    });
  }

  Future<void> _saveSettings() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      successMessage = null;
    });

    final ip = ipController.text.trim();
    final port = portController.text.trim();

    // Validate inputs
    if (!NetworkHelper.isValidIpAddress(ip)) {
      setState(() {
        isLoading = false;
        errorMessage = 'Invalid IP address format';
      });
      return;
    }

    if (!NetworkHelper.isValidPort(port)) {
      setState(() {
        isLoading = false;
        errorMessage = 'Invalid port number (1-65535)';
      });
      return;
    }

    // Save settings
    await AppPreferences.setIpAddress(ip);
    await AppPreferences.setPort(port);

    setState(() {
      isLoading = false;
      successMessage = 'Settings saved successfully!';
    });
  }

  void _setPreset(String ip, String port) {
    setState(() {
      ipController.text = ip;
      portController.text = port;
      errorMessage = null;
      successMessage = null;
      connectionStatus = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('API Settings')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Server Configuration',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ipController,
                    decoration: const InputDecoration(
                      labelText: 'IP Address',
                      hintText: '127.0.0.1 or 192.168.x.x',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: portController,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      hintText: '8080',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Quick Presets',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: () => _setPreset('127.0.0.1', '8080'),
                        child: const Text('Localhost'),
                      ),
                      ElevatedButton(
                        onPressed: () => _setPreset('192.168.1.1', '8080'),
                        child: const Text('Network IP'),
                      ),
                      ElevatedButton(
                        onPressed: () => _setPreset('10.0.2.2', '8080'),
                        child: const Text('Android Emulator'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (successMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              successMessage!,
                              style: const TextStyle(color: Colors.green),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (connectionStatus != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: connectionStatus!.contains('success')
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        border: Border.all(
                          color: connectionStatus!.contains('success')
                              ? Colors.green
                              : Colors.orange,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            connectionStatus!.contains('success')
                                ? Icons.check_circle
                                : Icons.warning,
                            color: connectionStatus!.contains('success')
                                ? Colors.green
                                : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              connectionStatus!,
                              style: TextStyle(
                                color: connectionStatus!.contains('success')
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isTesting ? null : _testConnection,
                          icon: isTesting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.wifi_tethering),
                          label: const Text('Test Connection'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isLoading ? null : _saveSettings,
                          icon: const Icon(Icons.save),
                          label: const Text('Save'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Current API URL',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<String>(
                    future: AppPreferences.getApiBaseUrl(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Text(
                          snapshot.data!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        );
                      }
                      return const Text('Loading...');
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
