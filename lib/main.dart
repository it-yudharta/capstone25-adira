import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'main_page.dart';
import 'admin_pengajuan_screen.dart';
import 'admin_pendaftaran_screen.dart';
import 'agent_screen.dart';
import 'main_supervisor.dart';

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
  User? _cachedUser;
  bool _authChecked = false;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 100), () {
      setState(() => _opacity = 1.0);
    });

    Future.delayed(const Duration(seconds: 2), () {
      setState(() => _showSplash = false);
    });

    FirebaseAuth.instance.authStateChanges().listen((user) {
      setState(() {
        _cachedUser = user;
        _authChecked = true;
      });
    });
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
            ),
          ),
        ),
      );
    }

    if (!_authChecked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_cachedUser == null) {
      return LoginScreen();
    }

    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance
              .collection('users')
              .doc(_cachedUser!.uid)
              .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: const Color(0xFFF0F4F5),
            body: const Center(
              child: CircularProgressIndicator(color: const Color(0xFF0E5C36)),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text("Akun tidak ditemukan di database.")),
          );
        }

        final role = snapshot.data!.get('role');
        if (role == 'admin_pengajuan') {
          return AdminPengajuanScreen();
        } else if (role == 'admin_pendaftaran') {
          return AdminPendaftaranScreen();
        } else if (role == 'agent') {
          return AgentScreen();
        } else if (role == 'supervisor') {
          return MainSupervisor();
        } else {
          return const Scaffold(
            body: Center(child: Text("Role tidak dikenali.")),
          );
        }
      },
    );
  }
}
