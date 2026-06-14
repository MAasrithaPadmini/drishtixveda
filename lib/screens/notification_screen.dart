import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../prediction_screen.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(user!.uid)
            .collection("predictions") // ✅ FIXED
            .orderBy("created_at", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No notifications yet"));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final docId = docs[i].id;

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  // 🔴 unread dot
                  leading: data["read"] == true
                      ? null
                      : const Icon(Icons.circle, color: Colors.red, size: 10),

                  title: Text(data["symbol"] ?? ""),

                  // ✅ FIXED ACTUAL DISPLAY
                  subtitle: Text(
                    "Predicted: ${data["predicted_price"] ?? 0} | "
                        "Actual: ${data["actual_price"] == null ? "--" : data["actual_price"]}",
                  ),

                  trailing: const Icon(Icons.arrow_forward),

                  onTap: () async {
                    // ✅ mark as read
                    await FirebaseFirestore.instance
                        .collection("users")
                        .doc(user.uid)
                        .collection("predictions")
                        .doc(docId)
                        .update({"read": true});

                    // ✅ open prediction screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PredictionScreen(
                          stock: {
                            "tradingsymbol": data["symbol"],
                            "instrument_token": data["instrument_token"],
                            "exchange": data["exchange"] ?? "NSE",

                            // 🔥 pass cached data
                            "prediction_data": {
                              "current_price":
                              data["current_price"] ?? 0,
                              "predicted_price":
                              data["predicted_price"] ?? 0,
                              "confidence":
                              data["confidence"] ?? 0,
                              "trend": data["trend"] ?? "N/A",
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}