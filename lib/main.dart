import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drishtixveda/screens/notification_screen.dart';
import 'package:drishtixveda/screens/prediction_vs_actual_screen.dart';
import 'package:drishtixveda/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:drishtixveda/screens/accuracy_screen.dart';
import 'package:drishtixveda/screens/performance_screen.dart';
import 'predict_any_stock_screen.dart';
import 'prediction_history_screen.dart';
import 'ocr_portfolio_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:drishtixveda/screens/stock_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("🔔 Background message: ${message.notification?.title}");
}
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void handleNotificationClick(RemoteMessage message) {
  final data = message.data;

  String? screen = data["screen"];
  String? symbol = data["symbol"];

  if (screen == "stock" && symbol != null) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => StockDetailScreen(symbol: symbol),
      ),
    );
  } else if (screen == "history") {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => const PredictionHistoryScreen(),
      ),
    );
  }
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const DrishtiXVedaApp());
}

class DrishtiXVedaApp extends StatelessWidget {
  const DrishtiXVedaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'DrishtiXVeda',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        primaryColor: Colors.deepPurple,
      ),
      home: const SplashScreen(),
    );
  }
}

////////////////////////////////////////////////////////////
/// SPLASH
////////////////////////////////////////////////////////////

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {

    super.initState();

    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      handleNotificationClick(message);
    });

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        handleNotificationClick(message);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Text(
            "DrishtiXVeda",
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// WELCOME
////////////////////////////////////////////////////////////

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Widget button(String text, VoidCallback onTap, {bool filled = true}) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: filled
          ? ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white, // ✅ FIX (IMPORTANT)
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      )
          : OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.deepPurple, // ✅ FIX
          side: const BorderSide(color: Colors.deepPurple, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_graph,
                size: 80, color: Colors.deepPurple),
            const SizedBox(height: 20),
            const Text(
              "AI Stock Prediction",
              style:
              TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            button("Create Account", () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const RegisterScreen()),
              );
            }),
            const SizedBox(height: 14),
            button("Login", () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const LoginScreen()),
              );
            }, filled: false),
          ],
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// REGISTER
////////////////////////////////////////////////////////////

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() =>
      _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();

  Future register() async {
    try {
      if (password.text != confirm.text) {
        throw Exception("Passwords do not match");
      }

      final res = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text.trim(),
      );

      final user = res.user;

      if (user != null) {
        await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .set({
          "created_at": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      print("REGISTER ERROR: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Register failed: ${e.toString()}")),
      );
    }
  }


  Widget field(String label, TextEditingController controller,
      {bool hide = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        obscureText: hide,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Create Account")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            field("Email", email),
            field("Password", password, hide: true),
            field("Confirm Password", confirm, hide: true),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: register,
                child: const Text(
                  "Register",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// LOGIN
////////////////////////////////////////////////////////////

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();

  Future login() async {
    try {
      final result = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text.trim(),
      );

      print("✅ LOGIN SUCCESS: ${result.user?.uid}");

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );

    } catch (e) {
      print("❌ LOGIN ERROR: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: password,
              obscureText: true,
              decoration:
              const InputDecoration(labelText: "Password"),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => login(),
                child: const Text(
                  "Login",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// HOME DASHBOARD (🔥 PREMIUM)
/////////////////////////////////////////////////////////////// HOME DASHBOARD (🔥 PREMIUM)////////////////////////////////////////////////////////////
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      checkTerms(context);
    });
    setupFCM();
    checkProfileCompletion(); // ✅ IMPORTANT FIX

    // 🔔 FOREGROUND NOTIFICATIONS
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(message.notification!.title ?? "Notification"),
            content: Text(message.notification!.body ?? ""),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    });
  }

  // 🔔 FCM SETUP
  void setupFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    await messaging.requestPermission();

    String? token = await messaging.getToken();
    print("🔥 FCM TOKEN: $token");

    final user = FirebaseAuth.instance.currentUser;
    if (user != null && token != null) {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .set({"fcm_token": token}, SetOptions(merge: true));
    }
  }

  // ⚠️ PROFILE CHECK
  Future checkProfileCompletion() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();

    final data = doc.data();

    if (data == null || data["profile_completed"] != true) {
      Future.delayed(const Duration(milliseconds: 500), () {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Complete Your Profile"),
            content: const Text(
                "Add your details for better AI insights & tracking."),
            actions: [
              TextButton(
                child: const Text("Later"),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: const Text("Complete Now"),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ProfileScreen()),
                  );
                },
              ),
            ],
          ),
        );
      });
    }
  }
  Future<void> checkTerms(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    bool accepted = prefs.getBool("termsAccepted") ?? false;

    if (!accepted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text("Terms & Conditions"),
            content: const Text(
              "This app uses machine learning and deep learning models to generate stock predictions.\n\n"
                  "These predictions are for informational purposes only and NOT financial advice.\n\n"
                  "Stock market investments involve risk. Use this app at your own risk.",
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await prefs.setBool("termsAccepted", true);
                  Navigator.pop(context);
                },
                child: const Text("I Agree"),
              ),
            ],
          );
        },
      );
    }
  }
  // 🎨 CARD UI (UNCHANGED)
  Widget premiumCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      // 🔥 APP BAR
      appBar: AppBar(
        title: const Text("DrishtiXVeda"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,

        // 👤 PROFILE LEFT
        leading: IconButton(
          icon: const Icon(Icons.person, color: Colors.pinkAccent),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ProfileScreen()),
            );
          },
        ),

        // 🔔 RIGHT SIDE
        actions: [
          // 🔔 NOTIFICATION WITH LIVE BADGE
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("users")
                .doc(user!.uid)
                .collection("predictions") // ✅ USE SAME COLLECTION
                .where("read", isEqualTo: false) // ✅ ONLY UNREAD
                .snapshots(),
            builder: (context, snapshot) {
              int count = snapshot.data?.docs.length ?? 0;

              return IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationScreen(),
                    ),
                  );
                },
                icon: Stack(
                  children: [
                    const Icon(Icons.notifications, color: Colors.redAccent),

                    if (count > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            "$count",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          // 🔓 LOGOUT
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pop(context);
            },
          ),
        ],
      ),

      // 🔥 BODY
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          children: [

            // ⚠️ PROFILE WARNING
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection("users")
                  .doc(user!.uid)
                  .get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();

                final data =
                snapshot.data!.data() as Map<String, dynamic>?;

                if (data?["profile_completed"] == true) {
                  return const SizedBox();
                }

                return Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    "⚠️ Complete your profile for better insights",
                    style: TextStyle(color: Colors.orange),
                  ),
                );
              },
            ),

            // 🔥 HEADER (PERSONALIZED)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const Text("Welcome 👋",
                      style: TextStyle(color: Colors.white70)),

                  const SizedBox(height: 6),

                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection("users")
                        .doc(user.uid)
                        .get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox();
                      }

                      final data = snapshot.data!.data()
                      as Map<String, dynamic>?;

                      return Text(
                        data?["name"] ?? user.email ?? "",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    "AI-powered stock insights & predictions",
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

            // 🔥 FEATURES (UNCHANGED)
            premiumCard("Portfolio OCR", Icons.image, Colors.purple, () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const OCRPortfolioScreen()));
            }),

            premiumCard("Predict Any Stock", Icons.show_chart,
                Colors.green, () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const PredictAnyStockScreen()));
                }),

            premiumCard("Prediction History", Icons.history,
                Colors.orange, () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const PredictionHistoryScreen()));
                }),

            premiumCard("Accuracy Tracking", Icons.analytics,
                Colors.blue, () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AccuracyScreen()));
                }),

            premiumCard("Model Performance", Icons.insights,
                Colors.teal, () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const PerformanceScreen()));
                }),
            premiumCard(
              "Prediction vs Actual",
              Icons.compare_arrows,
              Colors.orange,
                  () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PredictionVsActualScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}