import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MealPlannerScreen extends StatefulWidget {
  final String bookingId; // link to specific booking

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

  // Booking date range
  DateTime? _bookingStart;
  DateTime? _bookingEnd;

  // Meal Options from Firestore
  Map<String, List<String>> mealOptions = {
    "breakfast": [],
    "lunch": [],
    "dinner": [],
  };

  // Selected meal values
  String? _selectedBreakfast;
  String? _selectedLunch;
  String? _selectedDinner;

  // Notes controllers
  final TextEditingController _breakfastNotes = TextEditingController();
  final TextEditingController _lunchNotes = TextEditingController();
  final TextEditingController _dinnerNotes = TextEditingController();

  // Staff status
  Map<String, String> _status = {
    "breakfast": "PENDING",
    "lunch": "PENDING",
    "dinner": "PENDING",
  };

  @override
  void initState() {
    super.initState();
    _initPlanner();
  }

  @override
  void dispose() {
    _breakfastNotes.dispose();
    _lunchNotes.dispose();
    _dinnerNotes.dispose();
    super.dispose();
  }

  // -------------------------------------------------------
  // Helpers
  // -------------------------------------------------------
  String _key(DateTime d) => DateFormat("yyyy-MM-dd").format(d);
  String _formatDate(DateTime d) =>
      DateFormat("EEEE, d MMMM yyyy").format(d);

  DateTime _parseDate(dynamic val) {
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
    return DateTime.now();
  }

  void _clearFields() {
    _selectedBreakfast = null;
    _selectedLunch = null;
    _selectedDinner = null;
    _breakfastNotes.clear();
    _lunchNotes.clear();
    _dinnerNotes.clear();

    _status = {
      "breakfast": "PENDING",
      "lunch": "PENDING",
      "dinner": "PENDING",
    };
  }

  // -------------------------------------------------------
  // MAIN INIT
  // -------------------------------------------------------
  Future<void> _initPlanner() async {
    setState(() => _isLoading = true);

    try {
      await _loadBookingRange();
      await _loadMealOptions();
      await _loadMealPlan();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error initializing: $e")));
    }

    setState(() => _isLoading = false);
  }

  // -------------------------------------------------------
  // Booking date range (check-in/out)
  // -------------------------------------------------------
  Future<void> _loadBookingRange() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snap = await _firestore
        .collection("parent")
        .doc(user.uid)
        .collection("bookings")
        .doc(widget.bookingId)
        .get();

    if (!snap.exists) return;

    final data = snap.data()!;
    final checkIn = _parseDate(data["checkInDate"]);
    final checkOut = _parseDate(data["checkOutDate"]);

    _bookingStart = checkIn;
    _bookingEnd = checkOut;

    // Clamp selected date inside booking range
    DateTime today = DateTime.now();
    if (today.isBefore(checkIn)) today = checkIn;
    if (today.isAfter(checkOut)) today = checkOut;

    _selectedDate = today;
  }

  // -------------------------------------------------------
  // Load meal options from root collection
  // -------------------------------------------------------
  Future<void> _loadMealOptions() async {
    final snap = await _firestore.collection("meal_options").get();

    if (snap.docs.isNotEmpty) {
      final data = snap.docs.first.data();

      mealOptions["breakfast"] =
      List<String>.from(data["breakfast"] ?? []);

      mealOptions["lunch"] =
      List<String>.from(data["lunch"] ?? []);

      mealOptions["dinner"] =
      List<String>.from(data["dinner"] ?? []);
    }
  }

  // -------------------------------------------------------
  // Load selected day's meal plan
  // -------------------------------------------------------
  Future<void> _loadMealPlan() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _clearFields();
    final dateKey = _key(_selectedDate);

    final snap = await _firestore
        .collection("parent")
        .doc(user.uid)
        .collection("bookings")
        .doc(widget.bookingId)
        .collection("mealPlans")
        .doc(dateKey)
        .get();

    if (!snap.exists) return;

    final data = snap.data()!;
    final meals = data["meals"] ?? {};
    final status = data["status"] ?? {};

    _selectedBreakfast = meals["breakfast"]?["title"];
    _breakfastNotes.text = meals["breakfast"]?["notes"] ?? "";

    _selectedLunch = meals["lunch"]?["title"];
    _lunchNotes.text = meals["lunch"]?["notes"] ?? "";

    _selectedDinner = meals["dinner"]?["title"];
    _dinnerNotes.text = meals["dinner"]?["notes"] ?? "";

    _status = {
      "breakfast": status["breakfast"] ?? "PENDING",
      "lunch": status["lunch"] ?? "PENDING",
      "dinner": status["dinner"] ?? "PENDING",
    };
  }

  // -------------------------------------------------------
  // Date Picker
  // -------------------------------------------------------
  Future<void> _pickDate() async {
    if (_bookingStart == null || _bookingEnd == null) return;

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: _bookingStart!,
      lastDate: _bookingEnd!,
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
      await _loadMealPlan();
    }
  }

  // -------------------------------------------------------
  // Save Meal Plan
  // -------------------------------------------------------
  Future<void> _saveMealPlan() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    final dateKey = _key(_selectedDate);
    Map<String, dynamic> meals = {};

    void addMeal(String key, String? selectedMeal, TextEditingController notes) {
      if (selectedMeal != null) {
        meals[key] = {
          "title": selectedMeal,
          "notes": notes.text.trim(),
        };
      }
    }

    addMeal("breakfast", _selectedBreakfast, _breakfastNotes);
    addMeal("lunch", _selectedLunch, _lunchNotes);
    addMeal("dinner", _selectedDinner, _dinnerNotes);

    if (meals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one meal")),
      );
      setState(() => _isSaving = false);
      return;
    }

    final mealStatus = {
      "breakfast": _status["breakfast"],
      "lunch": _status["lunch"],
      "dinner": _status["dinner"],
    };

    try {
      // Save under parent
      await _firestore
          .collection("parent")
          .doc(user.uid)
          .collection("bookings")
          .doc(widget.bookingId)
          .collection("mealPlans")
          .doc(dateKey)
          .set({
        "date": dateKey,
        "meals": meals,
        "status": mealStatus,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Save under root (for staff)
      await _firestore
          .collection("mealPlans")
          .doc("${widget.bookingId}_$dateKey")
          .set({
        "parentId": user.uid,
        "bookingId": widget.bookingId,
        "date": dateKey,
        "meals": meals,
        "status": mealStatus,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Meal plan saved successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Save failed: $e")));
    }

    setState(() => _isSaving = false);
  }

  // -------------------------------------------------------
  // UI BUILD
  // -------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: accent,
        elevation: 0,
        title: const Text("Meal Planner", style: TextStyle(fontFamily: "Poppins")),
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
              selectedMeal: _selectedBreakfast,
              mealList: mealOptions["breakfast"]!,
              notesCtrl: _breakfastNotes,
              status: _status["breakfast"]!,
              onChanged: (v) => setState(() => _selectedBreakfast = v),
            ),

            const SizedBox(height: 16),

            _buildMealCard(
              label: "Lunch",
              selectedMeal: _selectedLunch,
              mealList: mealOptions["lunch"]!,
              notesCtrl: _lunchNotes,
              status: _status["lunch"]!,
              onChanged: (v) => setState(() => _selectedLunch = v),
            ),

            const SizedBox(height: 16),

            _buildMealCard(
              label: "Dinner",
              selectedMeal: _selectedDinner,
              mealList: mealOptions["dinner"]!,
              notesCtrl: _dinnerNotes,
              status: _status["dinner"]!,
              onChanged: (v) => setState(() => _selectedDinner = v),
            ),

            const SizedBox(height: 24),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------
  // Date Selector Header
  // -------------------------------------------------------
  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_formatDate(_selectedDate),
                style: const TextStyle(
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ),
          TextButton(
            onPressed: _pickDate,
            child: const Text("Change",
                style: TextStyle(color: accent, fontFamily: "Poppins")),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // Meal Card
  // -------------------------------------------------------
  Widget _buildMealCard({
    required String label,
    required String? selectedMeal,
    required List<String> mealList,
    required TextEditingController notesCtrl,
    required String status,
    required Function(String?) onChanged,
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
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontFamily: "Poppins",
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: accent)),
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
                      color: statusColor),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Dropdown Meal Selector
          DropdownButtonFormField<String>(
            value: selectedMeal,
            items: mealList
                .map((meal) => DropdownMenuItem(
              value: meal,
              child:
              Text(meal, style: const TextStyle(fontFamily: "Poppins")),
            ))
                .toList(),
            onChanged: onChanged,
            decoration: _inputDecoration("Select $label meal"),
          ),

          const SizedBox(height: 10),

          // Notes
          TextField(
            controller: notesCtrl,
            maxLines: 2,
            decoration: _inputDecoration("Notes / special request"),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // Save Button
  // -------------------------------------------------------
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

  // Text Input Decoration
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
}
