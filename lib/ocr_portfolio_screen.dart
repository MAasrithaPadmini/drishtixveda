import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

// ✅ IMPORT YOUR EXISTING SCREEN
import 'prediction_screen.dart';

class OCRPortfolioScreen extends StatefulWidget {
  const OCRPortfolioScreen({super.key});

  @override
  State<OCRPortfolioScreen> createState() => _OCRPortfolioScreenState();
}

class _OCRPortfolioScreenState extends State<OCRPortfolioScreen> {
  final String backend = "https://api.drishtixveda.com";

  File? image;
  List predictions = [];
  bool loading = false;

  // ================= PICK IMAGE =================
  Future pickImage() async {
    final picker = ImagePicker();
    final XFile? picked =
    await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        image = File(picked.path);
      });
    }
  }

  // ================= UPLOAD =================
  Future uploadImage() async {
    if (image == null) return;

    setState(() {
      loading = true;
      predictions = [];
    });

    var request = http.MultipartRequest(
      "POST",
      Uri.parse("$backend/portfolio-ocr"),
    );

    request.files.add(
      await http.MultipartFile.fromPath("file", image!.path),
    );

    var response = await request.send();
    var body = await response.stream.bytesToString();

    print(body);

    if (response.statusCode != 200) {
      print("ERROR: $body");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Server Error")),
      );

      setState(() => loading = false);
      return;
    }

    final data = jsonDecode(body);

    setState(() {
      predictions = data["predictions"];
      loading = false;
    });
  }

  // ================= STOCK CARD =================
  Widget stockCard(Map s) {
    Color color = Colors.orange;

    if (s["signal"] == "BUY") color = Colors.green;
    if (s["signal"] == "SELL") color = Colors.red;

    return Card(
      color: Colors.white.withOpacity(0.9), // ✅ LIGHT + SOFT
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        title: Text(
          s["symbol"],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          "Current ₹${s["current_price"]} → Predicted ₹${s["predicted_price"]}",
        ),
        trailing: Text(
          s["signal"],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),

        // ✅ NAVIGATION UNCHANGED
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PredictionScreen(
                stock: {
                  "tradingsymbol": s["symbol"],
                  "instrument_token": s["instrument_token"],
                  "exchange": s["exchange"] ?? "NSE",
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ LIGHT TRANSPARENT BACKGROUND EFFECT
      backgroundColor: Colors.grey.shade50,

      appBar: AppBar(
        title: const Text("Portfolio OCR Prediction"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),

      body: Container(
        // ✅ SOFT GRADIENT FOR PREMIUM LIGHT LOOK
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

        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // SELECT IMAGE
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: pickImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF090040),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Select Portfolio Screenshot",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // ANALYZE
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: uploadImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF090040),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Analyze Portfolio",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),

                  ),
                ),
              ),

              const SizedBox(height: 20),

              if (loading) const CircularProgressIndicator(),

              // LIST
              Expanded(
                child: predictions.isEmpty
                    ? const Center(
                  child: Text(
                    "No data yet",
                    style: TextStyle(color: Colors.black),
                  ),
                )
                    : ListView.builder(
                  itemCount: predictions.length,
                  itemBuilder: (context, i) {
                    return stockCard(predictions[i]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}