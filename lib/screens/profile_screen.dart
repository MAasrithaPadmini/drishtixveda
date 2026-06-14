import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final nameController = TextEditingController();
  final occupationController = TextEditingController();
  final dobController = TextEditingController();

  bool isEditing = false;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  // 🔥 LOAD DATA
  Future loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();

    final data = doc.data();

    if (data != null) {
      nameController.text = data["name"] ?? "";
      occupationController.text = data["occupation"] ?? "";
      dobController.text = data["dob"] ?? "";
    }
  }

  // 📅 DATE PICKER
  Future pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2005),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      dobController.text = picked.toIso8601String().split("T")[0];
      setState(() {});
    }
  }

  // 💾 SAVE PROFILE
  Future saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (nameController.text.isEmpty ||
        occupationController.text.isEmpty ||
        dobController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Please fill all fields")),
      );
      return;
    }

    setState(() => loading = true);

    await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .set({
      "name": nameController.text.trim(),
      "occupation": occupationController.text.trim(),
      "dob": dobController.text.trim(),
      "profile_completed": true,
    }, SetOptions(merge: true));

    await loadProfile();

    setState(() {
      loading = false;
      isEditing = false; // ✅ AUTO HIDE AFTER SAVE
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ Profile Saved")),
    );
  }

  // 🔥 DISPLAY TILE
  Widget infoTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            "$label: ",
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? "Not set" : value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // 🔤 INPUT FIELD
  Widget field(String label, TextEditingController controller,
      {bool readOnly = false, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFF161B22),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      // ✅ APPBAR WITH EDIT BUTTON
      appBar: AppBar(
        title: const Text("Profile"),
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.close : Icons.edit),
            onPressed: () {
              setState(() {
                isEditing = !isEditing;
              });
            },
          ),
        ],
      ),

      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection("users")
            .doc(user!.uid)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data =
          snapshot.data!.data() as Map<String, dynamic>?;

          return Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // 👤 ICON
                  const Center(
                    child: Icon(Icons.person,
                        size: 80, color: Colors.purple),
                  ),

                  const SizedBox(height: 20),

                  // 🔥 PROFILE INFO
                  infoTile("Email", user.email ?? ""),
                  infoTile("Name", data?["name"] ?? ""),
                  infoTile("Occupation", data?["occupation"] ?? ""),
                  infoTile("DOB", data?["dob"] ?? ""),
                  infoTile(
                    "Joined",
                    data?["created_at"] != null
                        ? data!["created_at"].toDate().toString()
                        : "N/A",
                  ),

                  // ✏️ EDIT SECTION (ONLY WHEN CLICKED)
                  if (isEditing) ...[
                    const SizedBox(height: 25),

                    const Text(
                      "Edit Details",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 15),

                    field("Name", nameController),
                    field("Occupation", occupationController),
                    field(
                      "Date of Birth",
                      dobController,
                      readOnly: true,
                      onTap: pickDate,
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: loading ? null : saveProfile,
                        child: loading
                            ? const CircularProgressIndicator()
                            : const Text("Save Profile"),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // 🔓 LOGOUT
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        Navigator.pop(context);
                      },
                      child: const Text("Logout"),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}