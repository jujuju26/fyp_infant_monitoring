import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen>
    with TickerProviderStateMixin {
  final AccentColor = const Color(0xFFC2868B);

  User? get currentUser => FirebaseAuth.instance.currentUser;

  /// local cache of visible cart docs
  List<QueryDocumentSnapshot> latestCartItems = [];

  /// checkbox state: docId -> bool
  Map<String, bool> selectedItems = {};

  double get totalSelectedPrice {
    double sum = 0.0;
    for (final doc in latestCartItems) {
      final data = doc.data()! as Map<String, dynamic>;
      final double price = (data['price'] ?? 0).toDouble();
      final int qty = (data['quantity'] ?? 1) as int;
      if (selectedItems[doc.id] == true) {
        sum += price * qty;
      }
    }
    return sum;
  }

  bool get anySelected => selectedItems.values.any((v) => v);
  bool get allVisibleSelected {
    if (latestCartItems.isEmpty) return false;
    for (final doc in latestCartItems) {
      if (selectedItems[doc.id] != true) return false;
    }
    return true;
  }

  /// Updates quantity on the cart document
  Future<void> updateQuantity(String docId, int newQuantity) async {
    if (newQuantity < 1) return;
    await FirebaseFirestore.instance
        .collection('parent')
        .doc(currentUser!.uid)
        .collection('cart')
        .doc(docId)
        .update({'quantity': newQuantity});
  }

  Future<void> deleteItem(String docId) async {
    await FirebaseFirestore.instance
        .collection('parent')
        .doc(currentUser!.uid)
        .collection('cart')
        .doc(docId)
        .delete();

    setState(() {
      selectedItems.remove(docId);
    });
  }

  Future<void> addToCart(Map<String, dynamic> itemData) async {
    final cartCollection = FirebaseFirestore.instance
        .collection("parent")
        .doc(currentUser!.uid)
        .collection("cart");

    final packageId = itemData['packageId'];
    if (packageId == null) {
      // Fallback to name if packageId not present (not recommended)
      final existingByName = await cartCollection
          .where("name", isEqualTo: itemData["name"])
          .limit(1)
          .get();

      if (existingByName.docs.isNotEmpty) {
        final doc = existingByName.docs.first;
        final currentQty = (doc["quantity"] ?? 1) as int;
        await cartCollection.doc(doc.id).update({
          "quantity": currentQty + (itemData["quantity"] ?? 1),
        });
      } else {
        await cartCollection.add(itemData);
      }
      return;
    }

    final existing = await cartCollection
        .where("packageId", isEqualTo: packageId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      final doc = existing.docs.first;
      final currentQty = (doc["quantity"] ?? 1) as int;
      await cartCollection.doc(doc.id).update({
        "quantity": currentQty + (itemData["quantity"] ?? 1),
        "addedAt": Timestamp.now(), // optional: refresh addedAt
      });
    } else {
      await cartCollection.add(itemData);
    }
  }

  /// Called when user presses checkout
  void onCheckout(List<QueryDocumentSnapshot> cartItems) async {
    final selectedDocs = cartItems.where((doc) => selectedItems[doc.id] == true);

    if (selectedDocs.isEmpty) return;

    // collect package data for CheckoutScreen
    final selectedPackages = selectedDocs
        .map((doc) => {
      ...((doc.data() ?? {}) as Map<String, dynamic>),
      'cartDocId': doc.id,
    })
        .toList();

    // Remove selected items from cart (delete cart docs)
    for (final doc in selectedDocs) {
      await deleteItem(doc.id);
    }

    setState(() {
      selectedItems.clear();
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          selectedPackages: selectedPackages.cast<Map<String, dynamic>>(),
        ),
      ),
    );
  }

  /// Merge duplicate cart docs that refer to the same packageId (happens if old entries exist)
  /// This will consolidate quantity into one doc per packageId using a batch write.
  Future<void> _mergeDuplicateCartDocs(List<QueryDocumentSnapshot> docs) async {
    if (docs.isEmpty) return;

    final collRef = FirebaseFirestore.instance
        .collection('parent')
        .doc(currentUser!.uid)
        .collection('cart');

    // Group by packageId; fallback to name if not present
    final Map<String, List<QueryDocumentSnapshot>> groups = {};
    for (final d in docs) {
      final data = d.data()! as Map<String, dynamic>;
      final key = (data['packageId'] ?? data['name'] ?? d.id).toString();
      groups.putIfAbsent(key, () => []).add(d);
    }

    final batch = FirebaseFirestore.instance.batch();
    var hasMerge = false;

    for (final entry in groups.entries) {
      final list = entry.value;
      if (list.length <= 1) continue;

      // Consolidate into the first doc
      final keeper = list.first;
      int totalQty = 0;
      Map<String, dynamic> keeperData = (keeper.data() ?? {}) as Map<String, dynamic>;

      for (final dup in list) {
        final data = (dup.data() ?? {}) as Map<String, dynamic>;
        totalQty += (data['quantity'] ?? 1) as int;
      }

      // Update keeper with combined quantity
      batch.update(collRef.doc(keeper.id), {'quantity': totalQty, 'mergedAt': Timestamp.now()});

      // Delete other duplicates
      for (final dup in list.skip(1)) {
        batch.delete(collRef.doc(dup.id));
      }

      hasMerge = true;
    }

    if (hasMerge) {
      try {
        await batch.commit();
      } catch (e) {
        // swallow errors but you may want to log
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Cart"),
          backgroundColor: Colors.white,
          foregroundColor: AccentColor,
          elevation: 0,
        ),
        body: const Center(child: Text("Please log in to view your cart.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Cart"),
        backgroundColor: Colors.white,
        foregroundColor: AccentColor,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("parent")
              .doc(currentUser!.uid)
              .collection("cart")
              .orderBy("addedAt", descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              latestCartItems = [];
              selectedItems.clear();

              return const Center(
                child: Text(
                  "Your cart is empty",
                  style: TextStyle(fontFamily: "Poppins"),
                ),
              );
            }

            final cartItems = snapshot.data!.docs;

            // Merge duplicates server-side if any (one-time per snapshot update).
            // We don't await here to avoid blocking the UI; merges will reflect on next snapshot.
            _mergeDuplicateCartDocs(cartItems);

            // Keep selectedItems map in sync with current visible docs
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final ids = cartItems.map((d) => d.id).toSet();
              bool changed = false;

              final removeKeys = selectedItems.keys
                  .where((k) => !ids.contains(k))
                  .toList();

              for (final k in removeKeys) {
                selectedItems.remove(k);
                changed = true;
              }

              for (final d in cartItems) {
                if (!selectedItems.containsKey(d.id)) {
                  selectedItems[d.id] = false;
                  changed = true;
                }
              }

              latestCartItems = cartItems;

              if (changed) setState(() {});
            });

            return Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          Checkbox(
                            value: allVisibleSelected,
                            activeColor: AccentColor,
                            onChanged: (val) {
                              setState(() {
                                for (final d in cartItems) {
                                  selectedItems[d.id] = val == true;
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              allVisibleSelected
                                  ? "All selected (${cartItems.length})"
                                  : "You have ${cartItems.length} package${cartItems.length > 1 ? 's' : ''} in your cart",
                              style: const TextStyle(
                                fontFamily: "Poppins",
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          if (anySelected)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  for (final d in cartItems) {
                                    selectedItems[d.id] = false;
                                  }
                                });
                              },
                              child: const Text("Clear"),
                            ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: cartItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = cartItems[index];
                          final data =
                          item.data()! as Map<String, dynamic>;

                          final images =
                          (data["images"] as List<dynamic>? ?? [])
                              .cast<String>();
                          final imageName =
                          images.isNotEmpty ? images[0] : "default_suite.jpg";
                          final name = data["name"] ?? "Package Name";
                          final double price =
                          (data["price"] ?? 0).toDouble();
                          final int quantity =
                          (data["quantity"] ?? 1) as int;

                          final bool isSelected =
                              selectedItems[item.id] ?? false;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 6,
                                  offset: Offset(0, 3),
                                )
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  activeColor: AccentColor,
                                  onChanged: (value) {
                                    setState(() {
                                      selectedItems[item.id] = value ?? false;
                                    });
                                  },
                                ),

                                // Fixed size image prevents Row overflow
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.asset(
                                    "assets/images/$imageName",
                                    width: 90,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
                                ),

                                const SizedBox(width: 12),

                                // Main details take remaining space
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: "Poppins",
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFC2868B),
                                        ),
                                      ),
                                      const SizedBox(height: 6),

                                      Text(
                                        "\$${(price * quantity).toStringAsFixed(2)}",
                                        style: const TextStyle(
                                          fontFamily: "Poppins",
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black87,
                                        ),
                                      ),

                                      const SizedBox(height: 12),

                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons
                                                .remove_circle_outline),
                                            color: AccentColor,
                                            onPressed: () async {
                                              if (quantity > 1) {
                                                await updateQuantity(
                                                    item.id, quantity - 1);
                                              } else {
                                                // if quantity == 1, deleting or keeping 1 is your choice.
                                                // Here we'll keep minimum 1.
                                              }
                                            },
                                          ),
                                          Text(
                                            quantity.toString(),
                                            style: const TextStyle(
                                              fontFamily: "Poppins",
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons
                                                .add_circle_outline),
                                            color: AccentColor,
                                            onPressed: () async {
                                              await updateQuantity(
                                                  item.id, quantity + 1);
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                IconButton(
                                  icon:
                                  const Icon(Icons.delete_outline),
                                  color: Colors.grey[700],
                                  onPressed: () async {
                                    final confirmed =
                                    await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text("Remove item"),
                                        content: const Text(
                                            "Are you sure you want to remove this item from your cart?"),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx)
                                                    .pop(false),
                                            child: const Text("Cancel"),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx)
                                                    .pop(true),
                                            child: const Text("Remove"),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirmed == true) {
                                      await deleteItem(item.id);
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 96),
                  ],
                ),

                if (anySelected)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Material(
                      elevation: 12,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Total Price",
                                    style: TextStyle(
                                      fontFamily: "Poppins",
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TweenAnimationBuilder<double>(
                                    tween: Tween<double>(
                                        begin: 0.0,
                                        end: totalSelectedPrice),
                                    duration: const Duration(
                                        milliseconds: 400),
                                    builder: (context, value, child) {
                                      return Text(
                                        "\$${value.toStringAsFixed(2)}",
                                        style: const TextStyle(
                                          fontFamily: "Poppins",
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.black87,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 10),

                            SizedBox(
                              height: 46,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFADADD),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(30),
                                  ),
                                  padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 12),
                                  elevation: 3,
                                  shadowColor: Colors.black26,
                                ),
                                onPressed: () {
                                  final selectedCartItems =
                                  latestCartItems
                                      .where((doc) =>
                                  selectedItems[doc.id] ==
                                      true)
                                      .toList();

                                  if (selectedCartItems.isEmpty) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            "Please select at least one package to checkout."),
                                      ),
                                    );
                                    return;
                                  }

                                  onCheckout(selectedCartItems);
                                },
                                child: const Text(
                                  "Check Out",
                                  style: TextStyle(
                                    fontFamily: "Poppins",
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
