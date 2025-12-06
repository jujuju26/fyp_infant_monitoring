import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'staff_add_meal_screen.dart';

class MealScreen extends StatefulWidget {
  const MealScreen({Key? key}) : super(key: key);

  @override
  _MealScreenState createState() => _MealScreenState();
}

class _MealScreenState extends State<MealScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedMotherId;

  final Color pinkColor = const Color(0xFFC2868B); // pink color for dropdown & icons

  // Fetching parents from Firestore
  Future<List<Map<String, dynamic>>> _fetchParents() async {
    final snapshot = await _firestore.collection('parent').get();
    return snapshot.docs.map((doc) => {
      'id': doc.id,
      'name': doc['username'] ?? 'Unknown Parent',
    }).toList();
  }

  Stream<List<Map<String, dynamic>>> _fetchMealPlans() {
    if (_selectedMotherId == null) return Stream.value([]);

    return _firestore
        .collection('parent')
        .doc(_selectedMotherId)
        .collection('meal')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _deleteMealPlan(String mealPlanId) async {
    try {
      await _firestore
          .collection('parent')
          .doc(_selectedMotherId)
          .collection('meal')
          .doc(mealPlanId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meal plan deleted successfully.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: Container(
          color: Colors.white,
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
                          color: Color(0xFFC2868B),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.fastfood, color: pinkColor),
                title: const Text('Add Meal Plan',
                    style: TextStyle(fontFamily: 'Poppins')),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const StaffAddMealScreen()),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.logout, color: pinkColor),
                title: const Text('Logout',
                    style: TextStyle(fontFamily: 'Poppins')),
                onTap: _logout,
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: pinkColor),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Image.asset('assets/images/logo2.png', height: 40),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dropdown to select parent
            FutureBuilder<List<Map<String, dynamic>>>(
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

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.black26, width: 1.3),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.grey,
                        offset: Offset(0, 2),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: DropdownButton<String>(
                    value: _selectedMotherId,
                    hint: Text(
                      "Select Parent",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        color: pinkColor,
                      ),
                    ),
                    onChanged: (newValue) {
                      setState(() {
                        _selectedMotherId = newValue;
                      });
                    },
                    items: parents.map((parent) {
                      return DropdownMenuItem<String>(
                        value: parent['id'],
                        child: Row(
                          children: [
                            Icon(Icons.person, color: pinkColor),
                            const SizedBox(width: 8),
                            Text(
                              parent['name'],
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                color: pinkColor,
                                fontWeight: _selectedMotherId == parent['id']
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    isExpanded: true,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      color: pinkColor,
                    ),
                    icon: Icon(Icons.arrow_drop_down, color: pinkColor),
                    iconSize: 30,
                    underline: Container(),
                    dropdownColor: Colors.white,
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Meal Plan List
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _fetchMealPlans(),
                builder: (context, snapshot) {
                  if (_selectedMotherId == null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.family_restroom,
                              size: 120, color: pinkColor.withOpacity(0.3)),
                          const SizedBox(height: 20),
                          const Text(
                            "Please select a parent to view meal plans.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.restaurant_menu,
                              size: 100, color: pinkColor.withOpacity(0.3)),
                          const SizedBox(height: 15),
                          const Text(
                            "No meal plans found.",
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final mealPlans = snapshot.data!;

                  return ListView.builder(
                    itemCount: mealPlans.length,
                    itemBuilder: (context, index) {
                      final mealPlan = mealPlans[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 6,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Icon(Icons.restaurant_menu, color: pinkColor, size: 30),
                          title: Text(mealPlan['mealDetails']),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Parent: ${mealPlan['motherName']}'),
                              const SizedBox(height: 4),
                              Text(
                                  'Dietary Needs: ${mealPlan['dietaryNeeds'].join(', ')}'),
                              Text(
                                  'Health Conditions: ${mealPlan['healthConditions']}'),
                              Text(
                                  'Allergies: ${mealPlan['hasAllergies'] ? 'Yes' : 'No'}'),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Text('Delete Meal Plan'),
                                    content: const Text(
                                        'Are you sure you want to delete this meal plan?'),
                                    actions: [
                                      TextButton(
                                        child: const Text('Cancel'),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                      TextButton(
                                        child: const Text('Delete'),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          _deleteMealPlan(mealPlan['id']);
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      );
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
