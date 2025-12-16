import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StaffInventoryScreen extends StatefulWidget {
  const StaffInventoryScreen({super.key});

  @override
  State<StaffInventoryScreen> createState() => _StaffInventoryScreenState();
}

class _StaffInventoryScreenState extends State<StaffInventoryScreen> {
  static const accent = Color(0xFFC2868B);

  bool _isLoading = true;
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  // ----------------------------------------------------------
  // LOAD INVENTORY (NULL SAFE)
  // ----------------------------------------------------------
  Future<void> _loadInventory() async {
    setState(() => _isLoading = true);

    final snap = await FirebaseFirestore.instance.collection("inventory").get();

    items = snap.docs.map((doc) {
      final d = doc.data();
      return {
        "id": doc.id,
        "name": d["name"] ?? "",
        "category": d["category"] ?? "",
        "unit": d["unit"] ?? "",
        "currentQty": d["currentQty"] ?? 0,
        "minQty": d["minQty"] ?? 0,
      };
    }).toList();

    setState(() => _isLoading = false);
  }

  // ----------------------------------------------------------
  // STAFF USE / DEDUCT ITEM
  // ----------------------------------------------------------
  Future<void> _deductItem(String itemId, int currentQty) async {
    int usedQty = 0;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Use Item"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Quantity Used"),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: usedQty > 0
                          ? () => setDialogState(() => usedQty--)
                          : null,
                    ),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        controller:
                        TextEditingController(text: usedQty.toString()),
                        onChanged: (v) {
                          final parsed = int.tryParse(v);
                          if (parsed != null && parsed >= 0) {
                            setDialogState(() => usedQty = parsed);
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () =>
                          setDialogState(() => usedQty++),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: accent),
                onPressed: () async {
                  if (usedQty <= 0) return;

                  final newQty =
                  (currentQty - usedQty).clamp(0, 999999);
                  final staff = FirebaseAuth.instance.currentUser;

                  // Update inventory quantity
                  await FirebaseFirestore.instance
                      .collection("inventory")
                      .doc(itemId)
                      .update({
                    "currentQty": newQty,
                    "updatedAt": FieldValue.serverTimestamp(),
                  });

                  // Log usage
                  await FirebaseFirestore.instance
                      .collection("inventory")
                      .doc(itemId)
                      .collection("usageLogs")
                      .add({
                    "staffId": staff?.uid ?? "unknown",
                    "quantityUsed": usedQty,
                    "timestamp": FieldValue.serverTimestamp(),
                  });

                  Navigator.pop(context);
                  _loadInventory();
                },
                child:
                const Text("Confirm", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ----------------------------------------------------------
  // UI
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F1F3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Inventory",
          style: TextStyle(
            color: accent,
            fontFamily: "Poppins",
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? const Center(child: Text("No items found"))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final bool lowStock =
              item["currentQty"] <= item["minQty"];

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              title: Text(
                item["name"],
                style: const TextStyle(
                  fontFamily: "Poppins",
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                "${item["category"]}\n"
                    "Qty: ${item["currentQty"]} ${item["unit"]}",
                style: TextStyle(
                  color: lowStock
                      ? Colors.red
                      : Colors.black54,
                  fontFamily: "Poppins",
                ),
              ),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _deductItem(
                    item["id"], item["currentQty"]),
                child: const Text("Use"),
              ),
            ),
          );
        },
      ),
    );
  }
}
