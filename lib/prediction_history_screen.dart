import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';

class PredictionHistoryScreen extends StatelessWidget {
  const PredictionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in")),
      );
    }

    final predictionsRef = FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("predictions")
        .orderBy("created_at", descending: true);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        centerTitle: true,
        title: const Text("Prediction History"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: predictionsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "No predictions yet",
                style: TextStyle(color: Colors.grey.shade600),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              final current = (data["current_price"] ?? 0).toDouble();
              final predicted = (data["predicted_price"] ?? 0).toDouble();
              final actualRaw = data["actual_price"];
              final actual = actualRaw == null ? null : (actualRaw as num).toDouble();

              final confidence = (data["confidence"] ?? 0).toDouble();
              final trend = data["trend"] ?? "";
              final signal = data["signal"] ?? "";

              final change = ((predicted - current) / (current == 0 ? 1 : current)) * 100;
              final isProfit = change > 0;

              final accuracy = (data["accuracy"] ?? 0).toDouble();
              final profit = (data["profit"] ?? 0).toDouble();
              final isProfitValue = profit >= 0;

              double? deviation;
              if (actual != null && predicted != 0) {
                deviation = ((actual - predicted) / predicted) * 100;
              }

              bool? isWithinRange;
              if (data["lower_bound"] != null &&
                  data["upper_bound"] != null &&
                  actual != null) {
                final lower = (data["lower_bound"] as num).toDouble();
                final upper = (data["upper_bound"] as num).toDouble();
                isWithinRange = actual >= lower && actual <= upper;
              }

              return ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isProfit
                            ? Colors.green.withOpacity(0.25)
                            : Colors.red.withOpacity(0.25),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // HEADER
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${data["symbol"]} (${data["exchange"]})",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "${isProfit ? "+" : ""}${change.toStringAsFixed(2)}%",
                              style: TextStyle(
                                color: isProfit ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // PRICES
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _priceTile("Current", current, Colors.blue),
                            _priceTile("Predicted", predicted, Colors.green),
                            if (actual != null)
                              _priceTile("Actual", actual, Colors.orange),
                          ],
                        ),

                        const SizedBox(height: 10),

                        LinearProgressIndicator(
                          value: predicted / (current + 1),
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade200,
                          color: isProfit ? Colors.green : Colors.red,
                        ),

                        const SizedBox(height: 12),

                        // TAGS
                        Wrap(
                          spacing: 8,
                          children: [
                            _chip(trend, trend == "UPTREND" ? Colors.green : Colors.red),
                            _chip(signal, signal == "BUY"
                                ? Colors.green
                                : signal == "SELL"
                                ? Colors.red
                                : Colors.orange),
                          ],
                        ),

                        const SizedBox(height: 12),

                        _progress("Confidence", confidence, Colors.teal),
                        const SizedBox(height: 8),
                        _progress("Accuracy", accuracy, _accuracyColor(accuracy)),

                        const SizedBox(height: 10),

                        _row(
                          "Profit / Loss",
                          "${isProfitValue ? "+" : ""}₹${profit.toStringAsFixed(2)}",
                          isProfitValue ? Colors.green : Colors.red,
                        ),

                        if (deviation != null)
                          _row(
                            "Deviation",
                            "${deviation.toStringAsFixed(2)} %",
                            deviation.abs() < 2 ? Colors.green : Colors.orange,
                          ),

                        if (isWithinRange != null)
                          _row(
                            "Range Hit",
                            isWithinRange ? "YES ✅" : "NO ❌",
                            isWithinRange ? Colors.green : Colors.red,
                          ),

                        const SizedBox(height: 10),

                        Divider(color: Colors.grey.shade200),

                        Text("Days: ${data["days"]}"),

                        if (data["created_at"] != null)
                          Text(
                            "Predicted: ${_formatDate(data["created_at"].toDate())}",
                            style: const TextStyle(fontSize: 12),
                          ),

                        if (data["target_date"] != null)
                          Text(
                            "Target: ${data["target_date"].toString().substring(0, 10)}",
                            style: const TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ================= HELPERS =================

  Widget _priceTile(String title, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title),
        Text(
          "₹${value.toStringAsFixed(2)}",
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(color: color)),
    );
  }

  Widget _progress(String title, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title),
        LinearProgressIndicator(
          value: (value / 100).clamp(0, 1),
          color: color,
        ),
        Text("${value.toStringAsFixed(1)}%"),
      ],
    );
  }

  Widget _row(String title, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title),
        Text(value, style: TextStyle(color: color)),
      ],
    );
  }

  Color _accuracyColor(double acc) {
    if (acc > 85) return Colors.green;
    if (acc > 65) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(DateTime dt) {
    return "${dt.day}/${dt.month}/${dt.year}";
  }
}