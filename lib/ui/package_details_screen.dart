import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class PackageDetailsScreen extends StatefulWidget {
  final String packageId;

  const PackageDetailsScreen({super.key, required this.packageId});

  @override
  State<PackageDetailsScreen> createState() => _PackageDetailsScreenState();
}

class _PackageDetailsScreenState extends State<PackageDetailsScreen> {
  static const accent = Color(0xFFC2868B);

  int _currentImage = 0;

  Future<String?> _getImageUrl(String path) async {
    try {
      final ref = FirebaseStorage.instance.ref(path);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        title: const Text(
          "Package Details",
          style: TextStyle(fontFamily: "Poppins", color: accent),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: accent),
      ),

      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection("package")
            .doc(widget.packageId)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: accent));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final String name = data['name'];
          final String description = data['description'];
          final double price = (data['price'] as num).toDouble();
          final List<String> images = List<String>.from(data['images'] ?? []);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// IMAGE CAROUSEL
                SizedBox(
                  height: 280,
                  child: Stack(
                    children: [
                      PageView.builder(
                        itemCount: images.length,
                        onPageChanged: (i) {
                          setState(() => _currentImage = i);
                        },
                        itemBuilder: (context, index) {
                          return FutureBuilder<String?>(
                            future: _getImageUrl(images[index]),
                            builder: (context, snap) {
                              if (!snap.hasData) {
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              return Image.network(
                                snap.data!,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              );
                            },
                          );
                        },
                      ),

                      /// CAROUSEL DOTS
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(images.length, (i) {
                            bool active = i == _currentImage;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin:
                              const EdgeInsets.symmetric(horizontal: 3),
                              width: active ? 10 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color:
                                active ? accent : Colors.white70,
                                borderRadius: BorderRadius.circular(20),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                /// PACKAGE NAME
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontFamily: "Poppins",
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: accent,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                /// DESCRIPTION
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    description,
                    style: const TextStyle(
                      fontFamily: "Poppins",
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                /// PRICE
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    "Price: RM ${price.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontFamily: "Poppins",
                      fontSize: 18,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }
}
