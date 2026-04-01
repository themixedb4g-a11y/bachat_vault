import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ForceUpdateScreen extends StatelessWidget {
  final String playStoreUrl;

  const ForceUpdateScreen({super.key, required this.playStoreUrl});

  Future<void> _launchStore() async {
    final Uri url = Uri.parse(playStoreUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $playStoreUrl');
    }
  }

  @override
  Widget build(BuildContext context) {
    // PopScope prevents the user from using the Android back button to escape
    return PopScope(
      canPop: false, 
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A), // Matches your dark theme
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.system_update_rounded, size: 80, color: Colors.tealAccent),
                const SizedBox(height: 24),
                const Text(
                  'Update Required',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'A new version of Bachat Vault is available.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _launchStore,
                    child: const Text('Update Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}