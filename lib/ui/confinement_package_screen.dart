import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'bookings_screen.dart';
import 'cart_screen.dart';
import 'logout_success_screen.dart';
import 'package_details_screen.dart';
import 'storage_image_helper.dart';

class ConfinementPackageScreen extends StatefulWidget {
  const ConfinementPackageScreen({super.key});

  @override
  State<ConfinementPackageScreen> createState() =>
      _ConfinementPackageScreenState();
}

class _ConfinementPackageScreenState extends State<ConfinementPackageScreen> {
  static const accent = Color(0xFFC2868B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // APP BAR
      appBar: AppBar(
        leading: Builder(
          builder: (context) =>
              IconButton(
                icon: const Icon(Icons.menu, color: accent),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
        ),
        title: Image.asset('assets/images/logo2.png', height: 40),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),

      // DRAWER
      drawer: const _AppDrawer(),

      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),

            // Packages Grid
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("package")
                    .orderBy("name")
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        "No packages available",
                        style: TextStyle(fontFamily: "Poppins"),
                      ),
                    );
                  }

                  final packages = snapshot.data!.docs;

                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisExtent: 330,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: packages.length,
                    itemBuilder: (context, index) {
                      final pkg = packages[index];
                      final List<String> images = List<String>.from(
                          pkg['images'] ?? []);
                      final String name = pkg['name'];
                      final double price = (pkg['price'] as num?)?.toDouble() ??
                          0.0;
                      final String details = pkg['description'] ?? '';

                      return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PackageDetailsScreen(packageId: pkg.id),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 6,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [

                                /// IMAGE SWIPER (FIREBASE STORAGE IMAGES)
                                ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    topRight: Radius.circular(16),
                                  ),
                                  child: SizedBox(
                                    height: 140,
                                    child: images.isEmpty
                                        ? Container(
                                      color: const Color(0xFFFADADD)
                                          .withOpacity(0.4),
                                      child: const Center(
                                        child: Icon(
                                          Icons.image_not_supported_outlined,
                                          size: 40,
                                          color: Colors.black38,
                                        ),
                                      ),
                                    )
                                        : Swiper(
                                      autoplay: true,
                                      pagination: const SwiperPagination(),
                                      itemCount: images.length,
                                      itemBuilder: (context, i) {
                                        final path = images[i];
                                        return ClipRRect(
                                          borderRadius:
                                          BorderRadius.circular(10),
                                          child: StorageHelper.networkImage(
                                            path,
                                            fit: BoxFit.cover,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),

                                /// PACKAGE DETAILS
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment
                                        .start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontFamily: "Poppins",
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "RM ${price.toStringAsFixed(2)}",
                                        style: const TextStyle(
                                          fontFamily: "Poppins",
                                          fontSize: 15,
                                          color: Colors.red,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        details,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: "Poppins",
                                          fontSize: 11,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      /// ADD TO CART
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: accent,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                              BorderRadius.circular(10),
                                            ),
                                          ),
                                          onPressed: () async {
                                            final user =
                                                FirebaseAuth.instance
                                                    .currentUser;
                                            if (user == null) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                      "Please login to add items to cart"),
                                                ),
                                              );
                                              return;
                                            }

                                            final cartRef = FirebaseFirestore
                                                .instance
                                                .collection('parent')
                                                .doc(user.uid)
                                                .collection('cart');

                                            await cartRef.add({
                                              'packageId': pkg.id,
                                              'name': name,
                                              'price': price,
                                              'quantity': 1,
                                              'images': images,
                                              'addedAt':
                                              FieldValue.serverTimestamp(),
                                            });

                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  "$name added to cart",
                                                  style: const TextStyle(
                                                      color: Colors.black),
                                                ),
                                                backgroundColor: Colors.green,
                                                duration:
                                                const Duration(seconds: 2),
                                              ),
                                            );
                                          },
                                          child: const Text(
                                            "Add to Cart",
                                            style: TextStyle(
                                              fontFamily: "Poppins",
                                              fontSize: 12,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ));
                      },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Drawer (unchanged, only imports updated)
class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFC2868B);

    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.white),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/logo2.png', height: 70),
                  const SizedBox(height: 10),
                  const Text(
                    'Caring made simple',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: accent,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.shopping_cart, color: accent),
            title:
            const Text('Cart', style: TextStyle(fontFamily: 'Poppins')),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const CartScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.book_online, color: accent),
            title: const Text('Bookings',
                style: TextStyle(fontFamily: 'Poppins')),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BookingsScreen(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: accent),
            title: const Text('Logout',
                style: TextStyle(fontFamily: 'Poppins')),
            onTap: () async {
              try {
                await FirebaseAuth.instance.signOut();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const LogoutSuccessScreen()),
                      (route) => false,
                );
              } catch (e) {
                debugPrint('Error signing out: $e');
              }
            },
          ),
        ],
      ),
    );
  }
}
