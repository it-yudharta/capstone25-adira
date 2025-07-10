// ignore_for_file: unused_import, use_key_in_widget_constructors, unnecessary_const

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'admin_pengajuan_screen.dart';
import 'admin_pendaftaran_screen.dart';
import 'agent_screen.dart';
import 'main_supervisor.dart';
import 'main_agent.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class UserCache {
  static String? role;

  static Future<void> saveRole(String role) async {
    role = role.trim();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('userRole', role);
    UserCache.role = role;
  }

  static Future<String?> loadRole() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    role = prefs.getString('userRole');
    return role;
  }

  static Future<void> clearRole() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('userRole');
    role = null;
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

    Future.delayed(const Duration(seconds: 2), () async {
      final role = await UserCache.loadRole();
      setState(() {
        _showSplash = false;
        UserCache.role = role;
      });
    });

    FirebaseAuth.instance.authStateChanges().first.then((user) async {
      _cachedUser = user;

      if (user != null && UserCache.role == null) {
        final doc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

        final role = doc.data()?['role'];
        if (role != null) {
          await UserCache.saveRole(role);
        }
      }

      setState(() {
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
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF0E5C36)),
        ),
      );
    }

    if (_cachedUser == null) {
      return LoginScreen();
    }

    if (UserCache.role != null) {
      switch (UserCache.role) {
        case 'admin_pengajuan':
          return AdminPengajuanScreen();
        case 'admin_pendaftaran':
          return AdminPendaftaranScreen();
        case 'agent':
          return MainAgent();
        case 'supervisor':
          return MainSupervisor();
        default:
          return const Scaffold(
            body: Center(child: Text("Role tidak dikenali.")),
          );
      }
    }

    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance
              .collection('users')
              .doc(_cachedUser!.uid)
              .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF0E5C36)),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text("Akun tidak ditemukan di database.")),
          );
        }

        final role = snapshot.data!.get('role');
        UserCache.role = role;

        switch (role) {
          case 'admin_pengajuan':
            return AdminPengajuanScreen();
          case 'admin_pendaftaran':
            return AdminPendaftaranScreen();
          case 'agent':
            return MainAgent();
          case 'supervisor':
            return MainSupervisor();
          default:
            return const Scaffold(
              body: Center(child: Text("Role tidak dikenali.")),
            );
        }
      },
    );
  }
}
