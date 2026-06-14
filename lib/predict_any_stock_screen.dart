import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:drishtixveda/screens/prediction_graph_screen.dart';

class PredictAnyStockScreen extends StatefulWidget {
  const PredictAnyStockScreen({super.key});

  @override
  State<PredictAnyStockScreen> createState() =>
      _PredictAnyStockScreenState();
}

class _PredictAnyStockScreenState extends State<PredictAnyStockScreen> {
  final String backendBase = "https://api.drishtixveda.com";
  final TextEditingController searchController = TextEditingController();
  List<dynamic> news = [];
  Timer? _debounce;
  List<Map<String, dynamic>> searchResults = [];
  Map<String, dynamic>? selectedStock;
  Map<String, dynamic>? prediction;

  bool loading = false;
  int selectedDays = 30;
  DateTime? selectedDate;

  List<FlSpot> historySpots = [];
  List<FlSpot> futureSpots = [];

  // ================= SEARCH =================
  void searchStock(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.isEmpty) {
      setState(() => searchResults = []);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final res = await http.get(
        Uri.parse("$backendBase/search?query=${query.toUpperCase()}"),
      );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);

        List stocks = [];

        if (decoded is List) {
          stocks = decoded;
        } else if (decoded["stocks"] != null) {
          stocks = decoded["stocks"];
        } else if (decoded["data"] != null) {
          stocks = decoded["data"];
        }

        setState(() {
          searchResults = stocks
              .map<Map<String, dynamic>>(
                  (e) => Map<String, dynamic>.from(e))
              .toList();
        });
      }
    });
  }

  // ================= DATE =================
  Future pickDate() async {
    final now = DateTime.now();

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
    if (selectedStock == null) return;

    final token = selectedStock!["instrument_token"];
    final exchange = selectedStock!["exchange"];

    final res = await http.get(Uri.parse(
        "$backendBase/candles?token=$token&exchange=$exchange&interval=1D"));

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);

      historySpots = decoded.asMap().entries.map<FlSpot>((e) {
        final close = (e.value["close"] as num).toDouble();
        return FlSpot(e.key.toDouble(), close);
      }).toList();
    }
  }

  // ================= BUILD GRAPH =================
  void buildChartData() {
    if (prediction == null || historySpots.isEmpty) return;

    final current = historySpots.last.y;
    final predicted =
    (prediction!["predicted_price"] as num).toDouble();

    futureSpots.clear();

    for (int i = 1; i <= selectedDays; i++) {
      final progress = i / selectedDays;

      final price =
          current + (predicted - current) * progress;

      futureSpots.add(
        FlSpot(
          (historySpots.length - 1 + i).toDouble(),
          price,
        ),
      );
    }
  }

  // ================= LOAD PREDICTION =================
  Future<void> loadPrediction() async {
    if (selectedStock == null) return;

    final token = selectedStock!["instrument_token"];
    final exchange = selectedStock!["exchange"];
    final market = exchange == "BSE" ? "bse" : "nse";
    final user = FirebaseAuth.instance.currentUser;

    setState(() => loading = true);

    final res = await http.get(Uri.parse(
        "$backendBase/predict?symbol_token=$token&market=$market&days=$selectedDays&user_id=${user!.uid}"));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);

      setState(() {
        prediction = data;
        news = (data["news"] is List) ? data["news"] : []; // ✅ ADD THIS
        loading = false;
      });

      await loadHistory();
      buildChartData();
    } else {
      setState(() => loading = false);
    }
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
      confidence =
          (prediction!["confidence"] as num).toDouble();

      signal = finalSignal(current, predicted, confidence);
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text("Predict Any Stock"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _premiumCard(child: _searchBox()),

              const SizedBox(height: 20),

              GestureDetector(
                onTap: pickDate,
                child: _premiumCard(
                  child: Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selectedDate == null
                            ? "Select Target Date"
                            : selectedDate!
                            .toString()
                            .split(' ')[0],
                      ),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),
              Text("≈ $selectedDays days"),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed:
                selectedStock == null ? null : loadPrediction,
                child: const Text("Run AI Prediction"),
              ),

              const SizedBox(height: 20),

              if (loading) const CircularProgressIndicator(),

              if (prediction != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                    signalColor(signal).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    signal,
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: signalColor(signal)),
                  ),
                ),

                const SizedBox(height: 20),

                _tile("Current Price",
                    "₹${current.toStringAsFixed(2)}",
                    Colors.blue),
                _tile("Predicted Price",
                    "₹${predicted.toStringAsFixed(2)}",
                    Colors.green),
                _tile("Return",
                    "${(((predicted - current) / current) * 100).toStringAsFixed(2)} %",
                    predicted > current
                        ? Colors.green
                        : Colors.red),
                _tile("Trend", prediction!["trend"],
                    prediction!["trend"] == "UPTREND"
                        ? Colors.green
                        : Colors.red),
                _tile("Signal", signal, signalColor(signal)),
                _tile("Confidence",
                    "${confidence.toStringAsFixed(1)} %",
                    Colors.cyan),

                const SizedBox(height: 20),

                // ✅ GRAPH BUTTON BACK
                ElevatedButton.icon(
                  icon: const Icon(Icons.show_chart),
                  label: const Text("View Graph"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PredictionGraphScreen(
                          historySpots: historySpots,
                          futureSpots: futureSpots,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

// ================= MARKET NEWS =================
                if (news.isNotEmpty) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Market News 📰",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 10),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: news.length,
                    itemBuilder: (context, i) {
                      final n = news[i];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n["title"] ?? "",
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    n["source"] ?? "",
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              n["sentiment"] == "POSITIVE"
                                  ? "🟢"
                                  : n["sentiment"] == "NEGATIVE"
                                  ? "🔴"
                                  : "🟡",
                              style: const TextStyle(fontSize: 18),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ]
            ],
          ),
        ),
      ),
    );
  }

  // ================= SEARCH UI =================
  Widget _searchBox() {
    return Column(
      children: [
        TextField(
          controller: searchController,
          decoration:
          const InputDecoration(hintText: "Search stock"),
          onChanged: searchStock,
        ),

        if (searchResults.isNotEmpty)
          Container(
            constraints:
            const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: searchResults.length,
              itemBuilder: (_, i) {
                final stock = searchResults[i];

                return ListTile(
                  title: Text(
                      "${stock["tradingsymbol"]} (${stock["exchange"]})"),
                  onTap: () {
                    setState(() {
                      selectedStock = stock;
                      searchResults.clear();
                      searchController.text =
                      stock["tradingsymbol"];
                    });

                    loadPrediction();
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _tile(String title, String value, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment:
        MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _premiumCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}