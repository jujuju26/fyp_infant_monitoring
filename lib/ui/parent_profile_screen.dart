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
              ? (data['created_at'] as Timestamp)
              .toDate()
              .toLocal()
              .toString()
              .split(' ')[0]
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

  // ================================================
  // ✔ FIXED UPLOAD PATH FOR STORAGE RULES
  // ================================================
  Future<void> _uploadProfileImage(File file) async {
    try {
      // Upload inside folder: profile_images/<uid>/profile.jpg
      final ref =
      _storage.ref().child('profile_images/$parentUid/profile.jpg');

      await ref.putFile(file);

      final url = await ref.getDownloadURL();

      // Update Firestore with final image URL
      await _firestore
          .collection('parent')
          .doc(parentUid)
          .update({'profileImageUrl': url});

      setState(() => profileImageUrl = url);
    } catch (e) {
      print('Error uploading profile image: $e');
    }
  }

  Future<void> _editField(String label, String currentValue, String fieldKey) async {
    final controller = TextEditingController(text: currentValue);
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: pinkSoft.withOpacity(0.15),
        title: Text(
          "Edit $label",
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: accent,
          ),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            validator: (v) =>
            v!.trim().isEmpty ? "$label cannot be empty" : null,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              hintText: "Enter new $label",
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accent),
            child: const Text("Save", style: TextStyle(color: Colors.white)),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await _firestore
                    .collection('parent')
                    .doc(parentUid)
                    .update({fieldKey: controller.text.trim()});
                _loadParentData();
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final newPass = TextEditingController();
    final confirm = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: pinkSoft.withOpacity(0.15),
        title: const Text(
          "Change Password",
          style: TextStyle(
            fontFamily: 'Poppins',
            color: accent,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: current,
                obscureText: true,
                validator: (v) =>
                v!.isEmpty ? "Enter current password" : null,
                decoration: _inputDecoration("Current Password"),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newPass,
                obscureText: true,
                validator: (v) =>
                v!.length < 6 ? "Min 6 characters" : null,
                decoration: _inputDecoration("New Password"),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirm,
                obscureText: true,
                validator: (v) =>
                v != newPass.text ? "Passwords do not match" : null,
                decoration: _inputDecoration("Confirm Password"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accent),
            child: const Text("Save", style: TextStyle(color: Colors.white)),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  User user = FirebaseAuth.instance.currentUser!;

                  final cred = EmailAuthProvider.credential(
                    email: user.email!,
                    password: current.text.trim(),
                  );

                  await user.reauthenticateWithCredential(cred);
                  await user.updatePassword(newPass.text.trim());

                  Navigator.pop(context);
                  _showSuccess("Password updated successfully!");
                } catch (e) {
                  Navigator.pop(context);
                  _showError("Current password is incorrect");
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showSuccess(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(msg, style: const TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(msg, style: const TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LogoutSuccessScreen()),
          (route) => false,
    );
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
            // ===============================
            // Profile Picture Section
            // ===============================
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: pinkSoft,
                backgroundImage: profileImage != null
                    ? FileImage(profileImage!)
                    : (profileImageUrl != null
                    ? NetworkImage(profileImageUrl!)
                    : null),
                child: profileImage == null && profileImageUrl == null
                    ? const Icon(Icons.person, color: accent, size: 60)
                    : null,
              ),
            ),

            const SizedBox(height: 16),

            // =====================================
            // Info Cards
            // =====================================

            _infoCard(
              children: [
                _editableInfoRow("Username", parentName, "username"),
                _editableInfoRow("Email", parentEmail, "email"),
                _passwordRow(),
              ],
            ),

            const SizedBox(height: 20),

            _infoCard(
              children: [
                _editableInfoRow("Phone Number", parentPhone, "phone"),
                _editableInfoRow("Address", parentAddress, "address"),
                _staticInfoRow("Account Type", "Parent"),
                _staticInfoRow("Joined Since", joinedSince),
              ],
            ),

            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: pinkSoft,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                  side: const BorderSide(color: Colors.black26),
                ),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =================================================
  // UI Helper Builders
  // =================================================

  Widget _infoCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8),
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
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
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
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
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
                fontSize: 14,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
