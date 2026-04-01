import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'screens/main_layout.dart'; 
import 'package:bachat_vault/screens/splash_screen.dart';
import 'screens/force_update_screen.dart';

// --- HELPER FUNCTION TO COMPARE VERSIONS (e.g., "1.0.5" vs "1.1.0") ---
bool isUpdateRequired(String currentVersion, String minVersion) {
  List<int> currentParts = currentVersion.split('.').map(int.parse).toList();
  List<int> minParts = minVersion.split('.').map(int.parse).toList();

  for (int i = 0; i < 3; i++) {
    int c = currentParts.length > i ? currentParts[i] : 0;
    int m = minParts.length > i ? minParts[i] : 0;
    if (c < m) return true; // App is older than minimum requirement
    if (c > m) return false; // App is newer than minimum requirement
  }
  return false; // Exactly the same version
}

Future<void> main() async {
  // 1. Capture the widget binding
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Tell Flutter to HOLD the splash screen on the screen
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  
  await dotenv.load(fileName: ".env");
  
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  bool needsUpdate = false;
  String playStoreUrl = '';

  // 3. SECURE BACKGROUND VERSION CHECK
  try {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String currentVersion = packageInfo.version;

    final response = await Supabase.instance.client
        .from('app_config')
        .select('min_version, play_store_url')
        .eq('id', 1)
        .single();

    String minVersion = response['min_version'];
    playStoreUrl = response['play_store_url'];

    needsUpdate = isUpdateRequired(currentVersion, minVersion);
  } catch (e) {
    debugPrint("Version check failed or offline: $e");
    // Failsafe: Let them in if the internet is down so the app doesn't brick
  }

  // 4. Force a 2-second delay so users see the logo
  await Future.delayed(const Duration(seconds: 2));
  
  // 5. Remove the splash screen just before running the app
  FlutterNativeSplash.remove();

  runApp(MyApp(needsUpdate: needsUpdate, playStoreUrl: playStoreUrl));
}

class MyApp extends StatelessWidget {
  final bool needsUpdate;
  final String playStoreUrl;

  const MyApp({
    super.key, 
    required this.needsUpdate, 
    required this.playStoreUrl
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bachat Vault',
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Colors.teal,
          secondary: Colors.tealAccent,
        ),
      ),
      // THE KILL SWITCH ROUTER:
      home: needsUpdate 
          ? ForceUpdateScreen(playStoreUrl: playStoreUrl) 
          : const SplashScreen(), // Keeps your original flow intact if no update is needed
    );
  }
}