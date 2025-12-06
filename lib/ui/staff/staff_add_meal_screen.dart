import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StaffAddMealScreen extends StatefulWidget {
  const StaffAddMealScreen({Key? key}) : super(key: key);

  @override
  _StaffAddMealScreenState createState() => _StaffAddMealScreenState();
}

class _StaffAddMealScreenState extends State<StaffAddMealScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  TextEditingController _mealDetailsController = TextEditingController();
  TextEditingController _healthConditionsController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  String? _selectedMotherId;
  String? _selectedMotherName;
  List<String> _selectedDietaryNeeds = [];
  bool _hasAllergies = false;

  // Fetching parents data from Firestore
  Future<List<Map<String, dynamic>>> _fetchParents() async {
    final snapshot = await _firestore.collection('parent').get();
    return snapshot.docs
        .map((doc) => {
      'id': doc.id,
      'name': doc['username'] ?? 'Unknown Parent',
    })
        .toList();
  }

  // Predefined dietary needs options
  List<String> _dietaryNeeds = [
    "Vegetarian",
    "Dairy-Free",
    "Low-Carb",
    "Keto",
    "Nut-Free",
    "Halal",
    "Kosher",
    "No Restrictions",
  ];

  // Add Meal Plan
  Future<void> _addMealPlan() async {
    if (_selectedMotherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a parent!')),
      );
      return;
    }

    if (_formKey.currentState?.validate() ?? false) {
      try {
        final mealPlanData = {
          'motherId': _selectedMotherId,
          'motherName': _selectedMotherName,
          'mealDetails': _mealDetailsController.text.trim(),
          'dietaryNeeds': _selectedDietaryNeeds,
          'hasAllergies': _hasAllergies,
          'healthConditions': _healthConditionsController.text.trim(),
          'createdAt': Timestamp.now(),
        };

        // Save meal plan to the "meal" subcollection under the selected parent
        await _firestore
            .collection('parent')
            .doc(_selectedMotherId)
            .collection('meal')
            .add(mealPlanData);

        // Clear inputs after adding
        _mealDetailsController.clear();
        _healthConditionsController.clear();
        setState(() {
          _selectedDietaryNeeds.clear();
          _hasAllergies = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal Plan Added Successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // UI for adding meal plan
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Meal Plan'),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(  // Wrap everything inside SingleChildScrollView
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Parent selection dropdown
            FutureBuilder<List<Map<String, dynamic>>>( // Future builder to fetch parents
              future: _fetchParents(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final parents = snapshot.data ?? [];
                if (parents.isEmpty) {
                  return const Text('No parents found in the database.');
                }

                return DropdownButtonFormField<String>(
                  value: _selectedMotherId,
                  onChanged: (newValue) {
                    setState(() {
                      _selectedMotherId = newValue;
                      _selectedMotherName = parents
                          .firstWhere((parent) => parent['id'] == newValue)['name'];
                    });
                  },
                  items: parents.map<DropdownMenuItem<String>>((parent) {
                    return DropdownMenuItem<String>(
                      value: parent['id'],
                      child: Text(parent['name']),
                    );
                  }).toList(),
                  decoration: const InputDecoration(
                    labelText: 'Select Parent',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Meal Details input field
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _mealDetailsController,
                    decoration: const InputDecoration(
                      labelText: 'Meal Details',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter meal details';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Dietary Needs Checkboxes
                  Wrap(
                    spacing: 12.0,
                    runSpacing: 8.0,
                    children: _dietaryNeeds.map((need) {
                      return FilterChip(
                        label: Text(need),
                        selected: _selectedDietaryNeeds.contains(need),
                        onSelected: (isSelected) {
                          setState(() {
                            if (isSelected) {
                              _selectedDietaryNeeds.add(need);
                            } else {
                              _selectedDietaryNeeds.remove(need);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Checkbox for allergies
                  CheckboxListTile(
                    title: const Text("Does the child have allergies?"),
                    value: _hasAllergies,
                    onChanged: (bool? newValue) {
                      setState(() {
                        _hasAllergies = newValue ?? false;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 20),

                  // Health Conditions input field
                  TextFormField(
                    controller: _healthConditionsController,
                    decoration: const InputDecoration(
                      labelText: 'Health Conditions',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit Button to Add Meal Plan
                  ElevatedButton(
                    onPressed: _addMealPlan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFADADD),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                        side: const BorderSide(color: Colors.black26, width: 1.3),
                      ),
                    ),
                    child: const Text(
                      "Add Meal Plan",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
