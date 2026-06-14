import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PerformanceScreen extends StatelessWidget {
  const PerformanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final ref = FirebaseFirestore.instance
        .collection("users")
        .doc(user!.uid)
        .collection("predictions");

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),

      appBar: AppBar(
        title: const Text("Model Performance"),
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
          stream: ref.snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            int total = 0;
            int correct = 0;
            double totalAccuracy = 0;

            int rangeCorrect = 0;

            for (var doc in snapshot.data!.docs) {
              final d = doc.data() as Map<String, dynamic>;

              final predicted =
              (d["predicted_price"] as num?)?.toDouble();
              final actual =
              (d["actual_price"] as num?)?.toDouble();
              final current =
              (d["current_price"] as num?)?.toDouble();

              final signal =
              (d["signal"] ?? "").toString().trim().toUpperCase();

              if (signal == "HOLD") continue;

              double? priceToUse;

              if (actual != null) {
                priceToUse = actual;
              } else if (current != null) {
                priceToUse = current;
              }

              if (priceToUse != null &&
                  predicted != null &&
                  current != null) {
                total++;

                double acc = 100 -
                    ((priceToUse - predicted).abs() /
                        priceToUse *
                        100);

                totalAccuracy += acc;

                double diff = priceToUse - current;

                if (diff.abs() < 0.01) continue;

                if (signal == "BUY" && diff > 0) {
                  correct++;
                } else if (signal == "SELL" && diff < 0) {
                  correct++;
                }

                if (actual != null &&
                    d["lower_bound"] != null &&
                    d["upper_bound"] != null) {
                  final lower =
                  (d["lower_bound"] as num).toDouble();
                  final upper =
                  (d["upper_bound"] as num).toDouble();

                  if (actual >= lower && actual <= upper) {
                    rangeCorrect++;
                  }
                }
              }
            }

            double avgAccuracy =
            total == 0 ? 0 : totalAccuracy / total;

            double winRate =
            total == 0 ? 0 : (correct / total) * 100;

            double rangeAccuracy =
            total == 0 ? 0 : (rangeCorrect / total) * 100;

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [

                  _glassCard(
                    "Total Predictions",
                    total.toString(),
                    Colors.blue,
                  ),

                  _glassCard(
                    "Avg Accuracy",
                    "${avgAccuracy.toStringAsFixed(1)}%",
                    Colors.green,
                  ),

                  _glassCard(
                    "Win Rate",
                    "${winRate.toStringAsFixed(1)}%",
                    Colors.purple,
                  ),

                  _glassCard(
                    "Range Accuracy",
                    "${rangeAccuracy.toStringAsFixed(1)}%",
                    Colors.orange,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ================= GLASS CARD =================
  Widget _glassCard(String title, String value, Color accent) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),

          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}