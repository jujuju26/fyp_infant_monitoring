import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'logout_success_screen.dart';

class ParentProfileScreen extends StatefulWidget {
  const ParentProfileScreen({super.key});

  @override
  State<ParentProfileScreen> createState() => _ParentProfileScreenState();
}

class _ParentProfileScreenState extends State<ParentProfileScreen> {
  static const accent = Color(0xFFC2868B);
  static const pinkSoft = Color(0xFFFADADD);

  final String parentUid = FirebaseAuth.instance.currentUser!.uid;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String parentName = "";
  String parentEmail = "";
  String parentPhone = "";
  String parentAddress = "";
  String joinedSince = "";

  File? profileImage;
  String? profileImageUrl;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadParentData();
  }

  Future<void> _loadParentData() async {
    try {
      final doc = await _firestore.collection('parent').doc(parentUid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          parentName = data['username'] ?? "Parent Name";
          parentEmail = data['email'] ?? "email@example.com";
          parentPhone = data['phone'] ?? "-";
          parentAddress = data['address'] ?? "-";
          joinedSince = data['created_at'] != null
              ? (data['created_at'] as Timestamp).toDate().toLocal().toString().split(' ')[0]
              : "Unknown";
          profileImageUrl = data['profileImageUrl'];
        });
      }
    } catch (e) {
      print('Error loading parent data: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        final file = File(picked.path);
        setState(() => profileImage = file);
        await _uploadProfileImage(file);
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<void> _uploadProfileImage(File file) async {
    try {
      final ref = _storage.ref().child('profile_images/$parentUid.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      await _firestore.collection('parent').doc(parentUid).update({'profileImageUrl': url});
      setState(() => profileImageUrl = url);
    } catch (e) {
      print('Error uploading profile image: $e');
    }
  }

  Future<void> _editField(String label, String currentValue, String fieldKey) async {
    final controller = TextEditingController(text: currentValue);
    final _formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: pinkSoft.withOpacity(0.15),
        title: Text(
          "Edit $label",
          style: const TextStyle(
              fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: accent),
        ),
        content: Form(
          key: _formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: fieldKey == 'email'
                ? TextInputType.emailAddress
                : TextInputType.text,
            validator: (value) {
              if (value == null || value.trim().isEmpty) return '$label cannot be empty';
              if (fieldKey == 'email' &&
                  !RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$").hasMatch(value.trim())) {
                return 'Enter a valid email';
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: "Enter new $label",
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.black54, fontFamily: 'Poppins'),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final newValue = controller.text.trim();
                await _firestore.collection('parent').doc(parentUid).update({fieldKey: newValue});
                _loadParentData();
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: accent),
            child: const Text(
              "Save",
              style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final _formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: pinkSoft.withOpacity(0.15),
        title: const Text(
          "Change Password",
          style: TextStyle(
              fontFamily: 'Poppins', color: accent, fontWeight: FontWeight.w600),
        ),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentController,
                obscureText: true,
                validator: (v) =>
                v!.isEmpty ? "Enter current password" : null,
                decoration: _inputDecoration("Current Password"),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newController,
                obscureText: true,
                validator: (v) =>
                v!.length < 6 ? "Min 6 characters" : null,
                decoration: _inputDecoration("New Password"),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmController,
                obscureText: true,
                validator: (v) =>
                v != newController.text ? "Passwords do not match" : null,
                decoration: _inputDecoration("Confirm Password"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel",
                style: TextStyle(fontFamily: 'Poppins', color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                try {
                  User user = FirebaseAuth.instance.currentUser!;

                  final cred = EmailAuthProvider.credential(
                    email: user.email!,
                    password: currentController.text.trim(),
                  );

                  await user.reauthenticateWithCredential(cred);
                  await user.updatePassword(newController.text.trim());

                  Navigator.pop(context);

                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      content: const Text(
                        "Password updated successfully!",
                        style: TextStyle(fontFamily: 'Poppins'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("OK"),
                        )
                      ],
                    ),
                  );
                } catch (e) {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      content: const Text(
                        "Current password is incorrect.",
                        style: TextStyle(fontFamily: 'Poppins'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("OK"),
                        )
                      ],
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: accent),
            child: const Text(
              "Save",
              style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontFamily: 'Poppins'),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LogoutSuccessScreen()),
            (route) => false,
      );
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Image.asset('assets/images/logo2.png', height: 40),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Profile Picture
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: pinkSoft,
                backgroundImage: profileImage != null
                    ? FileImage(profileImage!)
                    : profileImageUrl != null
                    ? NetworkImage(profileImageUrl!) as ImageProvider
                    : null,
                child: profileImage == null && profileImageUrl == null
                    ? const Icon(Icons.person, color: accent, size: 60)
                    : null,
              ),
            ),
            const SizedBox(height: 16),

            // Personal Info Card
            _infoCard(
              children: [
                _editableInfoRow("Username", parentName, "username"),
                _editableInfoRow("Email", parentEmail, "email"),

                // 🔥 NEW: Change Password Row
                _passwordRow(),
              ],
            ),

            const SizedBox(height: 20),

            // Contact Info Card
            _infoCard(
              children: [
                _editableInfoRow("Phone Number", parentPhone, "phone"),
                _editableInfoRow("Address", parentAddress, "address"),
                _staticInfoRow("Account Type", "Parent"),
                _staticInfoRow("Joined Since", joinedSince),
              ],
            ),

            const SizedBox(height: 40),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: pinkSoft,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                    side: const BorderSide(color: Colors.black26, width: 1.2),
                  ),
                  elevation: 3,
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _editableInfoRow(String label, String value, String fieldKey) {
    return GestureDetector(
      onTap: () => _editField(label, value, fieldKey),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                value,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: accent,
                    fontWeight: FontWeight.w500,
                    fontSize: 14),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.edit, color: Colors.black38, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _passwordRow() {
    return GestureDetector(
      onTap: _changePassword,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            const Expanded(
              flex: 2,
              child: Text(
                "Password",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ),
            const Expanded(
              flex: 3,
              child: Text(
                "●●●●●●●",
                style: TextStyle(
                    fontFamily: 'Poppins',
                    color: accent,
                    fontWeight: FontWeight.w500,
                    fontSize: 14),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.lock_outline, color: Colors.black38, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _staticInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: accent,
                  fontWeight: FontWeight.w500,
                  fontSize: 14),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
