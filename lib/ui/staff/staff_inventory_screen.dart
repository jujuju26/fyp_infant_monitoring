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
  static const lightPink = Color(0xFFFADADD);

  bool _isLoading = true;
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> filteredItems = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInventory();
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredItems = query.isEmpty
          ? items
          : items.where((item) {
        final name = item["name"].toString().toLowerCase();
        final category = item["category"].toString().toLowerCase();
        return name.contains(query) || category.contains(query);
      }).toList();
    });
  }

  /* ================= LOAD INVENTORY ================= */

  Future<void> _loadInventory() async {
    setState(() => _isLoading = true);

    final snap =
    await FirebaseFirestore.instance.collection("inventory").get();

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

    filteredItems = items;
    setState(() => _isLoading = false);
  }

  /* ================= USE / DEDUCT ================= */

  Future<void> _deductItem(
      String itemId,
      String itemName,
      int currentQty,
      String unit,
      ) async {
    int usedQty = 0;
    bool isLoading = false;
    String? errorMessage;
    final qtyController = TextEditingController(text: "0");

    late NavigatorState dialogNavigator;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        dialogNavigator = Navigator.of(dialogContext);

        return StatefulBuilder(
          builder: (_, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: const [
                  Icon(Icons.inventory_2, color: accent),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Use Item",
                      style: TextStyle(
                        fontFamily: "Poppins",
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(itemName,
                      style: const TextStyle(
                          fontFamily: "Poppins",
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text("Available: $currentQty $unit",
                      style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline,
                            color:
                            usedQty > 0 ? accent : Colors.grey, size: 32),
                        onPressed: usedQty > 0
                            ? () => setDialogState(() {
                          usedQty--;
                          qtyController.text = usedQty.toString();
                        })
                            : null,
                      ),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: qtyController,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                          onChanged: (v) {
                            final val = int.tryParse(v) ?? 0;
                            setDialogState(() {
                              usedQty = val;
                              errorMessage = val > currentQty
                                  ? "Cannot exceed available quantity"
                                  : null;
                            });
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline,
                            color: accent, size: 32),
                        onPressed: () => setDialogState(() {
                          if (usedQty < currentQty) {
                            usedQty++;
                            qtyController.text = usedQty.toString();
                            errorMessage = null;
                          }
                        }),
                      ),
                    ],
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(errorMessage!,
                        style:
                        const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                  if (isLoading) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => dialogNavigator.pop(),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: accent),
                  onPressed: usedQty > 0 &&
                      usedQty <= currentQty &&
                      !isLoading
                      ? () async {
                    setDialogState(() => isLoading = true);

                    final staff =
                        FirebaseAuth.instance.currentUser?.uid ??
                            "unknown";
                    final newQty =
                    (currentQty - usedQty).clamp(0, 999999);

                    await FirebaseFirestore.instance
                        .collection("inventory")
                        .doc(itemId)
                        .update({
                      "currentQty": newQty,
                      "updatedAt": FieldValue.serverTimestamp(),
                    });

                    await FirebaseFirestore.instance
                        .collection("inventory")
                        .doc(itemId)
                        .collection("usageLogs")
                        .add({
                      "staffId": staff,
                      "quantityUsed": usedQty,
                      "timestamp": FieldValue.serverTimestamp(),
                    });

                    dialogNavigator.pop();

                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Item used successfully"),
                        backgroundColor: Colors.green,
                      ),
                    );

                    _loadInventory();
                  }
                      : null,
                  child: isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Text("Confirm",
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /* ================= UI ================= */

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
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(accent)),
      )
          : RefreshIndicator(
        onRefresh: _loadInventory,
        color: accent,
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: filteredItems.isEmpty
                  ? _buildNoResultsState()
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredItems.length,
                itemBuilder: (_, i) =>
                    _buildInventoryCard(filteredItems[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ================= UI HELPERS (UNCHANGED) ================= */

  Widget _buildSearchBar() => Container(
    padding: const EdgeInsets.all(16),
    color: Colors.white,
    child: TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: "Search items or categories...",
        prefixIcon: const Icon(Icons.search, color: accent),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
          icon: const Icon(Icons.clear, color: accent),
          onPressed: _searchController.clear,
        )
            : null,
        filled: true,
        fillColor: const Color(0xFFF8F1F3),
        border:
        OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  Widget _buildInventoryCard(Map<String, dynamic> item) {
    final currentQty = item["currentQty"];
    final minQty = item["minQty"];
    final lowStock = currentQty <= minQty;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: lowStock
            ? const BorderSide(color: Colors.red, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _deductItem(
            item["id"], item["name"], currentQty, item["unit"]),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            "${item["name"]}\nQty: $currentQty ${item["unit"]}",
            style: const TextStyle(
                fontFamily: "Poppins", fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() =>
      const Center(child: Text("No Items Found"));

  Widget _buildNoResultsState() =>
      const Center(child: Text("No Results"));
}
