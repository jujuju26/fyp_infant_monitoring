import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../logout_success_screen.dart';

class StaffProfileScreen extends StatefulWidget {
  const StaffProfileScreen({super.key});

  @override
  State<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends State<StaffProfileScreen> {
  static const accent = Color(0xFFC2868B);
  static const pinkSoft = Color(0xFFFADADD);

  final String staffUid = FirebaseAuth.instance.currentUser!.uid;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String staffName = "";
  String staffEmail = "";
  String staffPhone = "";
  String staffAddress = "";
  String joinedSince = "";

  File? profileImage;
  String? profileImageUrl; // DIRECT download URL

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadStaffData();
  }

  // ==================================================
  // LOAD STAFF DATA WITH DIRECT IMAGE URL
  // ==================================================
  Future<void> _loadStaffData() async {
    try {
      final doc = await _firestore.collection('staff').doc(staffUid).get();
      if (!doc.exists) return;

      final data = doc.data()!;

      setState(() {
        staffName = data['username'] ?? "Staff Name";
        staffEmail = data['email'] ?? "email@example.com";
        staffPhone = data['phone'] ?? "-";
        staffAddress = data['address'] ?? "-";
        joinedSince = data['created_at'] != null
            ? (data['created_at'] as Timestamp)
            .toDate()
            .toLocal()
            .toString()
            .split(' ')[0]
            : "Unknown";

        // 🔥 parent-style: Firestore stores actual image URL
        profileImageUrl = data['profileImageUrl'];
      });
    } catch (e) {
      print("Error loading staff data: $e");
    }
  }

  // ==================================================
  // PICK IMAGE
  // ==================================================
  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        final file = File(picked.path);
        setState(() => profileImage = file);
        await _uploadProfileImage(file);
      }
    } catch (e) {
      print("Error picking image: $e");
    }
  }

  // ==================================================
  // UPLOAD IMAGE (MATCHES PARENT STYLE)
  // profile_images/<uid>/profile.jpg
  // ==================================================
  Future<void> _uploadProfileImage(File file) async {
    try {
      final ref = _storage.ref().child("profile_images/$staffUid/profile.jpg");

      await ref.putFile(file);

      // Get final URL
      final url = await ref.getDownloadURL();

      // Store URL directly (same as parent)
      await _firestore.collection('staff').doc(staffUid).update({
        "profileImageUrl": url,
      });

      setState(() {
        profileImageUrl = url;
      });
    } catch (e) {
      print("Error uploading profile image: $e");
    }
  }

  // ==================================================
  // EDITABLE FIELDS & PASSWORD
  // ==================================================
  Future<void> _editField(
      String label, String currentValue, String fieldKey) async {
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
              fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: accent),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            validator: (v) => v!.trim().isEmpty ? "$label cannot be empty" : null,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accent),
            child: const Text("Save", style: TextStyle(color: Colors.white)),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await _firestore
                    .collection('staff')
                    .doc(staffUid)
                    .update({fieldKey: controller.text.trim()});
                _loadStaffData();
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
        title: const Text("Change Password",
            style: TextStyle(fontFamily: 'Poppins', color: accent)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: current,
                obscureText: true,
                validator: (v) => v!.isEmpty ? "Enter current password" : null,
                decoration: _inputDecoration("Current Password"),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newPass,
                obscureText: true,
                validator: (v) => v!.length < 6 ? "Min 6 characters" : null,
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
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  User user = FirebaseAuth.instance.currentUser!;
                  final cred = EmailAuthProvider.credential(
                      email: user.email!, password: current.text.trim());
                  await user.reauthenticateWithCredential(cred);
                  await user.updatePassword(newPass.text.trim());
                  Navigator.pop(context);
                } catch (e) {
                  Navigator.pop(context);
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: accent),
            child:
            const Text("Save", style: TextStyle(color: Colors.white)),
          ),
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

  // ==================================================
  // UI — NO CHANGES (AS REQUESTED)
  // ==================================================
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

            _infoCard(
              children: [
                _editableInfoRow("Username", staffName, "username"),
                _editableInfoRow("Email", staffEmail, "email"),
                _passwordRow(),
              ],
            ),
            const SizedBox(height: 20),

            _infoCard(
              children: [
                _editableInfoRow("Phone Number", staffPhone, "phone"),
                _editableInfoRow("Address", staffAddress, "address"),
                _staticInfoRow("Account Type", "Staff"),
                _staticInfoRow("Joined Since", joinedSince),
              ],
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: pinkSoft,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                    side: const BorderSide(color: Colors.black26),
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
              color: Colors.black12, blurRadius: 8, offset: const Offset(0, 4)),
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
          children: const [
            Expanded(
              flex: 2,
              child: Text(
                "Password",
                style: TextStyle(
                    fontFamily: 'Poppins', color: Colors.grey, fontSize: 14),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                "●●●●●●●",
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontFamily: 'Poppins',
                    color: accent,
                    fontWeight: FontWeight.w500,
                    fontSize: 14),
              ),
            ),
            SizedBox(width: 5),
            Icon(Icons.lock_outline, color: Colors.black38, size: 18),
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
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: accent,
                  fontWeight: FontWeight.w500,
                  fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
