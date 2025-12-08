import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

/// Central helper for working with Firebase Storage images.
///
/// We always store only the Storage path in Firestore, e.g.:
///   "packages/1765015315507_deluxe1.png"
/// NOT the full download URL.
class StorageHelper {
  /// Returns a usable https download URL for a storage path or URL.
  /// - If [pathOrUrl] already starts with "http", it is returned as-is.
  /// - Otherwise, it is treated as a Firebase Storage path and we call getDownloadURL().
  static Future<String?> getImageUrl(String pathOrUrl) async {
    if (pathOrUrl.isEmpty) return null;

    // Already a URL
    if (pathOrUrl.startsWith('http')) return pathOrUrl;

    try {
      final ref = FirebaseStorage.instance.ref(pathOrUrl);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('StorageHelper.getImageUrl error for $pathOrUrl → $e');
      return null;
    }
  }

  /// Convenience widget to display an image from Storage / URL with placeholders.
  static Widget networkImage(
      String pathOrUrl, {
        BoxFit fit = BoxFit.cover,
        Widget? placeholder,
        Widget? errorWidget,
      }) {
    return FutureBuilder<String?>(
      future: getImageUrl(pathOrUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return placeholder ??
              Container(
                color: Colors.grey.shade100,
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
        }

        final url = snapshot.data;
        if (url == null || url.isEmpty) {
          return errorWidget ??
              Container(
                color: Colors.grey.shade200,
                child: const Center(
                  child: Icon(Icons.broken_image, color: Colors.grey),
                ),
              );
        }

        return Image.network(
          url,
          fit: fit,
        );
      },
    );
  }
}
