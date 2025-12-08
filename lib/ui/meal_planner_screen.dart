import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MealPlannerScreen extends StatefulWidget {
  final String bookingId; // 🔹 link to specific booking

  const MealPlannerScreen({
    Key? key,
    required this.bookingId,
  }) : super(key: key);

  @override
  State<MealPlannerScreen> createState() => _MealPlannerScreenState();
}

class _MealPlannerScreenState extends State<MealPlannerScreen> {
  static const Color accent = Color(0xFFC2868B);
  static const Color lightPink = Color(0xFFFADADD);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isSaving = false;

  // Booking date range (from booking check-in/out)
  DateTime? _bookingStart;
  DateTime? _bookingEnd;

  // 3 meal controllers
  final TextEditingController _breakfastTitle = TextEditingController();
  final TextEditingController _breakfastNotes = TextEditingController();
  final TextEditingController _breakfastCalories = TextEditingController();

  final TextEditingController _lunchTitle = TextEditingController();
  final TextEditingController _lunchNotes = TextEditingController();
  final TextEditingController _lunchCalories = TextEditingController();

  final TextEditingController _dinnerTitle = TextEditingController();
  final TextEditingController _dinnerNotes = TextEditingController();
  final TextEditingController _dinnerCalories = TextEditingController();

  // Staff status
  Map<String, String> _status = {
    "breakfast": "PENDING",
    "lunch": "PENDING",
    "dinner": "PENDING",
  };

  @override
  void initState() {
    super.initState();
    _initBookingAndMeal();
  }

  @override
  void dispose() {
    _breakfastTitle.dispose();
    _breakfastNotes.dispose();
    _breakfastCalories.dispose();
    _lunchTitle.dispose();
    _lunchNotes.dispose();
    _lunchCalories.dispose();
    _dinnerTitle.dispose();
    _dinnerNotes.dispose();
    _dinnerCalories.dispose();
    super.dispose();
  }

  // ------------------------------------------------
  // Helpers
  // ------------------------------------------------

  String _key(DateTime d) => DateFormat("yyyy-MM-dd").format(d);

  String _formatDate(DateTime d) =>
      DateFormat("EEEE, d MMMM yyyy").format(d);

  DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  void _clearFields() {
    _breakfastTitle.clear();
    _breakfastNotes.clear();
    _breakfastCalories.clear();

    _lunchTitle.clear();
    _lunchNotes.clear();
    _lunchCalories.clear();

    _dinnerTitle.clear();
    _dinnerNotes.clear();
    _dinnerCalories.clear();

    _status = {
      "breakfast": "PENDING",
      "lunch": "PENDING",
      "dinner": "PENDING",
    };
  }

  // ------------------------------------------------
  // Init: load booking dates + meal plan
  // ------------------------------------------------
  Future<void> _initBookingAndMeal() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // 1) Load booking to get check-in/out range
      final bookingDoc = await _firestore
          .collection("parent")
          .doc(user.uid)
          .collection("bookings")
          .doc(widget.bookingId)
          .get();

      if (bookingDoc.exists) {
        final data = bookingDoc.data()!;
        final checkIn = _parseDate(data["checkInDate"]);
        final checkOut = _parseDate(data["checkOutDate"]);

        _bookingStart = checkIn;
        _bookingEnd = checkOut;

        // Clamp selected date into booking range
        DateTime today = DateTime.now();
        DateTime selected = today;

        if (selected.isBefore(checkIn)) selected = checkIn;
        if (selected.isAfter(checkOut)) selected = checkOut;

        _selectedDate = selected;
      }

      // 2) Load meal plan for that date
      await _loadMealPlan();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load booking info: $e")),
      );
    }

    setState(() => _isLoading = false);
  }

  // ------------------------------------------------
  // Date picker
  // ------------------------------------------------
  Future<void> _pickDate() async {
    final now = DateTime.now();

    // If booking has range, constrain date picker to that
    final firstDate = _bookingStart ?? now.subtract(const Duration(days: 5));
    final lastDate = _bookingEnd ?? now.add(const Duration(days: 365));

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(firstDate)
          ? firstDate
          : (_selectedDate.isAfter(lastDate) ? lastDate : _selectedDate),
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
      await _loadMealPlan();
    }
  }

  // ------------------------------------------------
  // Load meal plan for selected date
  // parent/{uid}/bookings/{bookingId}/mealPlans/{dateKey}
  // ------------------------------------------------
  Future<void> _loadMealPlan() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      _clearFields();
      final dateKey = _key(_selectedDate);

      final doc = await _firestore
          .collection("parent")
          .doc(user.uid)
          .collection("bookings")
          .doc(widget.bookingId)
          .collection("mealPlans")
          .doc(dateKey)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final meals = data["meals"] ?? {};
        final status = data["status"] ?? {};

        // Breakfast
        final b = meals["breakfast"] ?? {};
        _breakfastTitle.text = b["title"] ?? "";
        _breakfastNotes.text = b["notes"] ?? "";
        _breakfastCalories.text = b["calories"]?.toString() ?? "";

        // Lunch
        final l = meals["lunch"] ?? {};
        _lunchTitle.text = l["title"] ?? "";
        _lunchNotes.text = l["notes"] ?? "";
        _lunchCalories.text = l["calories"]?.toString() ?? "";

        // Dinner
        final d = meals["dinner"] ?? {};
        _dinnerTitle.text = d["title"] ?? "";
        _dinnerNotes.text = d["notes"] ?? "";
        _dinnerCalories.text = d["calories"]?.toString() ?? "";

        _status = {
          "breakfast": status["breakfast"] ?? "PENDING",
          "lunch": status["lunch"] ?? "PENDING",
          "dinner": status["dinner"] ?? "PENDING",
        };
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load meal plan: $e")),
      );
    }

    setState(() => _isLoading = false);
  }

  // ------------------------------------------------
  // Save meal plan
  // parent/{uid}/bookings/{bookingId}/mealPlans/{dateKey}
  // + mirror to root: mealPlans/{bookingId}_{dateKey}
  // ------------------------------------------------
  Future<void> _saveMealPlan() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    final dateKey = _key(_selectedDate);

    final meals = <String, dynamic>{};

    void addMeal(
        String key,
        TextEditingController title,
        TextEditingController notes,
        TextEditingController calories,
        ) {
      if (title.text.trim().isNotEmpty ||
          notes.text.trim().isNotEmpty ||
          calories.text.trim().isNotEmpty) {
        meals[key] = {
          "title": title.text.trim(),
          "notes": notes.text.trim(),
          "calories": double.tryParse(calories.text.trim()),
        };
      }
    }

    addMeal("breakfast", _breakfastTitle, _breakfastNotes, _breakfastCalories);
    addMeal("lunch", _lunchTitle, _lunchNotes, _lunchCalories);
    addMeal("dinner", _dinnerTitle, _dinnerNotes, _dinnerCalories);

    if (meals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter at least one meal.")),
      );
      setState(() => _isSaving = false);
      return;
    }

    final mealStatus = {
      "breakfast": _status["breakfast"] ?? "PENDING",
      "lunch": _status["lunch"] ?? "PENDING",
      "dinner": _status["dinner"] ?? "PENDING",
    };

    try {
      // Save under booking (for parent)
      final parentDoc = _firestore
          .collection("parent")
          .doc(user.uid)
          .collection("bookings")
          .doc(widget.bookingId)
          .collection("mealPlans")
          .doc(dateKey);

      await parentDoc.set({
        "date": dateKey,
        "meals": meals,
        "status": mealStatus,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Save under root (for staff)
      final rootDoc = _firestore
          .collection("mealPlans")
          .doc("${widget.bookingId}_$dateKey");

      await rootDoc.set({
        "parentId": user.uid,
        "bookingId": widget.bookingId,
        "date": dateKey,
        "meals": meals,
        "status": mealStatus,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Meal plan saved.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Save failed: $e")),
      );
    }

    setState(() => _isSaving = false);
  }

  // ------------------------------------------------
  // UI BUILD
  // ------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: accent,
        elevation: 0,
        title: const Text(
          "Meal Planner",
          style: TextStyle(fontFamily: "Poppins"),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accent))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildDateSelector(),
            const SizedBox(height: 20),
            _buildMealCard(
              label: "Breakfast",
              status: _status["breakfast"]!,
              titleCtrl: _breakfastTitle,
              notesCtrl: _breakfastNotes,
              calCtrl: _breakfastCalories,
            ),
            const SizedBox(height: 16),
            _buildMealCard(
              label: "Lunch",
              status: _status["lunch"]!,
              titleCtrl: _lunchTitle,
              notesCtrl: _lunchNotes,
              calCtrl: _lunchCalories,
            ),
            const SizedBox(height: 16),
            _buildMealCard(
              label: "Dinner",
              status: _status["dinner"]!,
              titleCtrl: _dinnerTitle,
              notesCtrl: _dinnerNotes,
              calCtrl: _dinnerCalories,
            ),
            const SizedBox(height: 24),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------
  // Date Selector Header
  // ------------------------------------------------
  Widget _buildDateSelector() {
    String rangeText = "";
    if (_bookingStart != null && _bookingEnd != null) {
      rangeText =
      "Confinement stay: ${DateFormat('d MMM').format(_bookingStart!)} - ${DateFormat('d MMM yyyy').format(_bookingEnd!)}";
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, color: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _formatDate(_selectedDate),
                  style: const TextStyle(
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              TextButton(
                onPressed: _pickDate,
                child: const Text(
                  "Change",
                  style: TextStyle(color: accent, fontFamily: "Poppins"),
                ),
              ),
            ],
          ),
          if (rangeText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              rangeText,
              style: const TextStyle(
                fontFamily: "Poppins",
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------
  // Meal Card Widget
  // ------------------------------------------------
  Widget _buildMealCard({
    required String label,
    required String status,
    required TextEditingController titleCtrl,
    required TextEditingController notesCtrl,
    required TextEditingController calCtrl,
  }) {
    Color statusColor = Colors.grey;
    if (status == "PREPARING") statusColor = Colors.orange;
    if (status == "READY") statusColor = Colors.green;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: lightPink),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: "Poppins",
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontFamily: "Poppins",
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          TextField(
            controller: titleCtrl,
            decoration: _inputDecoration("Meal name (e.g. porridge)"),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: notesCtrl,
            maxLines: 2,
            decoration: _inputDecoration("Notes / special requests"),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: calCtrl,
            keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
            decoration: _inputDecoration("Estimated calories"),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFFDF5F6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  // ------------------------------------------------
  // Save button
  // ------------------------------------------------
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 2,
        ),
        onPressed: _isSaving ? null : _saveMealPlan,
        child: _isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
          "Save Meal Plan",
          style: TextStyle(
            fontFamily: "Poppins",
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
