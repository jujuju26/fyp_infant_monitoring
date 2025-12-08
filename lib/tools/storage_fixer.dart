import 'package:flutter/widgets.dart';        // <-- required for binding
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:fyp_infant_monitoring/firebase_options.dart';

Future<void> main() async {
  // 🔥 REQUIRED to prevent binding crash
  WidgetsFlutterBinding.ensureInitialized();

  print("🚀 Initializing Firebase...");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final storage = FirebaseStorage.instance;

  print("📂 Listing all files under /packages...");
  final ListResult result = await storage.ref("packages").listAll();

  if (result.items.isEmpty) {
    print("⚠ No files found in /packages.");
    return;
  }

  print("🔧 Starting token removal process...\n");

  for (final ref in result.items) {
    print("Processing → ${ref.fullPath}");

    try {
      final oldMeta = await ref.getMetadata();

      final newMeta = SettableMetadata(
        contentType: oldMeta.contentType,
        customMetadata: {},   // <-- removes all old tokens
      );

      await ref.updateMetadata(newMeta);

      print("   ✔ Token removed for: ${ref.name}\n");
    } catch (e) {
      print("   ❌ Failed to update ${ref.fullPath}");
      print("      Error → $e\n");
    }
  }

  print("🎉 DONE! All tokens removed successfully!");
}
