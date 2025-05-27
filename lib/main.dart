import 'package:flutter/material.dart';
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

        // route lainnya yang kamu perlukan, misalnya
        '/pengajuan': (context) => AdminPengajuanScreen(),
        '/saved': (context) => SavedOrdersScreen(),
      },
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
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
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return Scaffold(
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
                return Scaffold(
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
