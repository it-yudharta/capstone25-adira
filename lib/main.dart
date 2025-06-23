import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'pendaftaran_screen.dart';
import 'generate_qr_screen.dart';
import 'saved_pendaftaran_screen.dart';
import 'saved_orders_screen.dart';
import 'login_screen.dart';
import 'main_page.dart';
import 'admin_pengajuan_screen.dart';
import 'admin_pendaftaran_screen.dart';
import 'agent_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reseller App',
      theme: ThemeData(primarySwatch: Colors.blue),
      routes: {
        '/pendaftaran': (context) => PendaftaranScreen(),
        '/qr': (context) => GenerateQRScreen(),
        '/saved_pendaftaran': (context) => SavedPendaftaranScreen(),
        '/pengajuan': (context) => AdminPengajuanScreen(),
        '/saved': (context) => SavedOrdersScreen(),
      },
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _showSplash = true;
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration(milliseconds: 100), () {
      setState(() => _opacity = 1.0);
    });

    Future.delayed(const Duration(seconds: 2), () {
      setState(() => _showSplash = false);
    });
  }

  Widget splashLoading() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          'assets/images/Splash.png',
          width: MediaQuery.of(context).size.width * 0.6,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: AnimatedOpacity(
            duration: const Duration(seconds: 1),
            opacity: _opacity,
            child: Image.asset(
              'assets/images/Splash.png',
              width: MediaQuery.of(context).size.width * 0.6,
              fit: BoxFit.contain,
              alignment: Alignment.center,
            ),
          ),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return splashLoading();
          }
        }

        final user = snapshot.data;
        if (user == null) {
          return LoginScreen();
        } else {
          return FutureBuilder<DocumentSnapshot>(
            future:
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return splashLoading();
                }
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Scaffold(
                  body: Center(
                    child: Text("Akun tidak ditemukan di database."),
                  ),
                );
              }

              final role = snapshot.data!.get('role');
              if (role == 'supervisor') {
                return MainPage();
              } else if (role == 'admin_pengajuan') {
                return AdminPengajuanScreen();
              } else if (role == 'admin_pendaftaran') {
                return AdminPendaftaranScreen();
              } else if (role == 'agent') {
                return AgentScreen();
              } else {
                return const Scaffold(
                  body: Center(child: Text("Role tidak dikenali.")),
                );
              }
            },
          );
        }
      },
    );
  }
}
