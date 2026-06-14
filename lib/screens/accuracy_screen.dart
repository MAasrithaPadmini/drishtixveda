import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';

class AccuracyScreen extends StatelessWidget {
  const AccuracyScreen({super.key});

  double calculateAccuracy(double predicted, double actual) {
    return (1 - ((actual - predicted).abs() / actual)) * 100;
  }

  void showResultDialog(BuildContext context, Map<String, dynamic> data) {
    final predicted = (data["predicted_price"] as num).toDouble();
    final actual = (data["actual_price"] as num).toDouble();
    final accuracy = calculateAccuracy(predicted, actual);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Prediction Result 📊"),
        content: Text(
          "Predicted: ₹$predicted\n"
              "Actual: ₹$actual\n"
              "Accuracy: ${accuracy.toStringAsFixed(1)}%",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text("Accuracy Tracking"),
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
              .snapshots(),
          builder: (context, snapshot) {

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;

            if (docs.isEmpty) {
              return Center(
                child: Text(
                  "No data yet",
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              );
            }

            List<FlSpot> spots = [];
            double totalAccuracy = 0;
            int count = 0;

            for (int i = 0; i < docs.length; i++) {
              final data = docs[i].data() as Map<String, dynamic>;
              final docRef = docs[i].reference;

              final predicted = (data["predicted_price"] ?? 0).toDouble();
              final actual = (data["actual_price"] ?? 0).toDouble();
              final current = (data["current_price"] ?? 0).toDouble();

              // 🔔 Notification
              if (data["actual_price"] != null && data["notified"] != true) {
                Future.microtask(() async {
                  showResultDialog(context, data);
                  await docRef.update({"notified": true});
                });
              }

              double? accuracy;

              if (data["actual_price"] != null) {
                accuracy = calculateAccuracy(predicted, actual);
              } else {
                accuracy = calculateAccuracy(predicted, current);
              }

              if (accuracy != null) {
                totalAccuracy += accuracy;
                count++;
                spots.add(FlSpot(i.toDouble(), accuracy));
              }
            }

            double avgAccuracy =
            count == 0 ? 0 : totalAccuracy / count;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // 🔥 AVG CARD
                  _glassCard(
                    child: Column(
                      children: [
                        const Text("Average Accuracy",
                            style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 6),
                        Text(
                          "${avgAccuracy.toStringAsFixed(2)}%",
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 📈 GRAPH
                  _glassCard(
                    child: SizedBox(
                      height: 200,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(show: true),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              color: Colors.deepPurple,
                              barWidth: 3,
                              dotData: FlDotData(show: true),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Prediction Results",
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 10),

                  // 🔥 FIXED LIST
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {

                      final data = docs[index].data() as Map<String, dynamic>;

                      final predicted =
                      (data["predicted_price"] ?? 0).toDouble();
                      final actual =
                      (data["actual_price"] ?? 0).toDouble();

                      if (actual == 0) return const SizedBox();

                      final accuracy =
                      calculateAccuracy(predicted, actual);

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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data["symbol"] ?? "",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            Text("Predicted: ₹$predicted"),
                            Text("Actual: ₹$actual"),
                            const SizedBox(height: 6),
                            Text(
                              "Accuracy: ${accuracy.toStringAsFixed(2)}%",
                              style: TextStyle(
                                color: accuracy > 80
                                    ? Colors.green
                                    : Colors.red,
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
                            const SizedBox(height: 4),
                            Text(
                              "Target Date: ${data["target_date"]?.substring(0, 10) ?? "N/A"}",
                              style: TextStyle(
                                  color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      );
                    },
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
  Widget _glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}