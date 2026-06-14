import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PredictionVsActualScreen extends StatelessWidget {
  const PredictionVsActualScreen({super.key});

  double calculateAccuracy(double predicted, double actual) {
    return (1 - ((actual - predicted).abs() / actual)) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),

      appBar: AppBar(
        title: const Text("Prediction vs Actual"),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white,
              Colors.deepPurple.withOpacity(0.05),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),

        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("users")
              .doc(user!.uid)
              .collection("predictions")
              .orderBy("created_at", descending: true)
              .snapshots(),
          builder: (context, snapshot) {

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;

            if (docs.isEmpty) {
              return Center(
                child: Text(
                  "No predictions yet",
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {

                final data = docs[index].data() as Map<String, dynamic>;

                final symbol = data["symbol"] ?? "";
                final predicted =
                (data["predicted_price"] ?? 0).toDouble();
                final actual =
                (data["actual_price"] ?? 0).toDouble();

                if (actual == 0) return const SizedBox();

                final accuracy = calculateAccuracy(predicted, actual);

                double deviation =
                    ((actual - predicted) / predicted) * 100;

                bool? isWithinRange;
                if (data["lower_bound"] != null &&
                    data["upper_bound"] != null) {
                  final lower = (data["lower_bound"]).toDouble();
                  final upper = (data["upper_bound"]).toDouble();
                  isWithinRange =
                      actual >= lower && actual <= upper;
                }

                return _glassCard(
                  accuracy,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // 🔥 SYMBOL
                      Text(
                        symbol,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text("Predicted Price: ₹$predicted"),
                      Text("Actual Price: ₹$actual"),

                      const SizedBox(height: 8),

                      Text(
                        "Accuracy: ${accuracy.toStringAsFixed(2)}%",
                        style: TextStyle(
                          color:
                          accuracy > 80 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      Text(
                        "Deviation: ${deviation.toStringAsFixed(2)}%",
                        style: TextStyle(
                          color: deviation.abs() < 2
                              ? Colors.green
                              : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      if (isWithinRange != null)
                        Text(
                          "Range Hit: ${isWithinRange ? "YES ✅" : "NO ❌"}",
                          style: TextStyle(
                            color: isWithinRange
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                      const SizedBox(height: 6),

                      Text(
                        "Predicted On: ${data["created_at"] != null ? (data["created_at"].toDate().toString().substring(0, 10)) : "N/A"}",
                        style:
                        TextStyle(color: Colors.grey.shade600),
                      ),

                      Text(
                        "Target Date: ${data["target_date"]?.substring(0, 10) ?? "N/A"}",
                        style:
                        TextStyle(color: Colors.grey.shade600),
                      ),

                      Text(
                        "Days: ${data["days"] ?? "-"}",
                        style:
                        TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ================= GLASS CARD =================
  Widget _glassCard(double accuracy, {required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(18),

            border: Border.all(
              color: accuracy > 80
                  ? Colors.green.withOpacity(0.4)
                  : Colors.red.withOpacity(0.4),
            ),

            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}