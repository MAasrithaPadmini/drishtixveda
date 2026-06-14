import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:drishtixveda/screens/prediction_graph_screen.dart';

class PredictionScreen extends StatefulWidget {
  final Map<String, dynamic> stock;

  const PredictionScreen({super.key, required this.stock});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  Map<String, dynamic>? prediction;
  bool loading = false;

  final String backendBase = "https://api.drishtixveda.com";

  int selectedDays = 30;
  DateTime? selectedDate;

  List<FlSpot> historySpots = [];
  List<FlSpot> futureSpots = [];

  @override
  void initState() {
    super.initState();

    if (widget.stock["prediction_data"] != null) {
      prediction = widget.stock["prediction_data"];
      loadHistory().then((_) => buildChartData());
    } else {
      Future.microtask(() => loadPrediction());
    }
  }

  // ================= DATE =================
  Future<void> pickDate() async {
    DateTime now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
        selectedDays = picked.difference(now).inDays;
      });
    }
  }

  // ================= SIGNAL =================
  String finalSignal(double current, double predicted, double confidence) {
    double change = ((predicted - current) / current) * 100;

    if (confidence < 60) return "HOLD";
    if (change > 2) return "BUY";
    if (change < -2) return "SELL";

    return "HOLD";
  }

  Color signalColor(String s) {
    if (s == "BUY") return Colors.green;
    if (s == "SELL") return Colors.red;
    return Colors.orange;
  }

  // ================= LOAD HISTORY =================
  Future<void> loadHistory() async {
    final token = widget.stock["instrument_token"];
    final exchange = widget.stock["exchange"];

    final res = await http.get(
      Uri.parse("$backendBase/candles?token=$token&exchange=$exchange"),
    );

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);

      historySpots = decoded.asMap().entries.map<FlSpot>((e) {
        final close = (e.value["close"] as num).toDouble();
        return FlSpot(e.key.toDouble(), close);
      }).toList();
    }
  }

  // ================= LOAD PREDICTION =================
  Future<void> loadPrediction() async {
    final token = widget.stock["instrument_token"];
    final exchange = widget.stock["exchange"];
    final market = exchange == "BSE" ? "bse" : "nse";

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    setState(() => loading = true);

    final res = await http.get(
      Uri.parse(
          "$backendBase/predict?symbol_token=$token&market=$market&days=$selectedDays&user_id=${user.uid}"),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);

      setState(() {
        prediction = data;
        loading = false;
      });

      await loadHistory();
      buildChartData();
    } else {
      setState(() => loading = false);
    }
  }

  // ================= GRAPH =================
  void buildChartData() {
    if (prediction == null || historySpots.isEmpty) return;

    final current = historySpots.last.y;
    final predicted =
    (prediction!["predicted_price"] as num).toDouble();

    futureSpots.clear();

    for (int i = 1; i <= selectedDays; i++) {
      final progress = i / selectedDays;

      final price = current + (predicted - current) * progress;

      futureSpots.add(
        FlSpot(
          (historySpots.length - 1 + i).toDouble(),
          price,
        ),
      );
    }
  }

  double expectedReturn() {
    final c = (prediction!["current_price"] as num).toDouble();
    final p = (prediction!["predicted_price"] as num).toDouble();

    return ((p - c) / c) * 100;
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    double current = 0;
    double predicted = 0;
    double confidence = 0;
    String signal = "HOLD";

    if (prediction != null) {
      current = (prediction!["current_price"] as num).toDouble();
      predicted =
          (prediction!["predicted_price"] as num).toDouble();
      confidence = (prediction!["confidence"] as num).toDouble();

      signal = finalSignal(current, predicted, confidence);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(widget.stock["tradingsymbol"]),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _card(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(selectedDate == null
                      ? "Select Target Date"
                      : selectedDate!.toString().split(' ')[0]),
                  const Icon(Icons.calendar_today, size: 18),
                ],
              ),
              onTap: pickDate,
            ),

            const SizedBox(height: 14),

            _mainButton("Run AI Prediction", loadPrediction),

            const SizedBox(height: 18),

            if (loading) const CircularProgressIndicator(),

            if (prediction != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      signalColor(signal).withOpacity(0.15),
                      signalColor(signal).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Text(
                      signal,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: signalColor(signal),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "AI Recommendation",
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              _infoTile("Current Price",
                  "₹${current.toStringAsFixed(2)}", Colors.blue),
              _infoTile("Predicted Price",
                  "₹${predicted.toStringAsFixed(2)}", Colors.green),
              _infoTile(
                  "Expected Return",
                  "${expectedReturn().toStringAsFixed(2)} %",
                  expectedReturn() > 0 ? Colors.green : Colors.red),
              _infoTile(
                  "Trend",
                  prediction!["trend"],
                  prediction!["trend"] == "UPTREND"
                      ? Colors.green
                      : Colors.red),
              _infoTile("Confidence",
                  "${confidence.toStringAsFixed(1)} %", Colors.purple),

              const SizedBox(height: 16),

              _mainButton("View Graph", () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PredictionGraphScreen(
                      historySpots: historySpots,
                      futureSpots: futureSpots,
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  // ================= UI HELPERS =================

  Widget _card({required Widget child, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      ),
    );
  }

  Widget _infoTile(String title, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _mainButton(String text, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: const Color(0xFF6A11CB),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}