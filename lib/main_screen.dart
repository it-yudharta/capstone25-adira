import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'saved_orders_screen.dart';
import 'generate_qr_screen.dart';
import 'pengajuan_screen.dart';
import 'pendaftaran_screen.dart';
import 'login_screen.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();

    // Listener untuk mendeteksi perubahan status autentikasi
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user == null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("ResellerApp - Home"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: ListView(
          padding: EdgeInsets.all(20),
          children: [
            MenuButton(
              icon: Icons.assignment,
              label: "Pengajuan",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PengajuanScreen()),
                );
              },
            ),
            MenuButton(
              icon: Icons.list_alt,
              label: "Pesanan Tersimpan",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SavedOrdersScreen()),
                );
              },
            ),
            MenuButton(
              icon: Icons.qr_code,
              label: "Generate QR Code",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GenerateQRScreen()),
                );
              },
            ),
            MenuButton(
              icon: Icons.person_add,
              label: "Pendaftaran Reseller",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PendaftaranScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const MenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          minimumSize: Size(double.infinity, 50),
          backgroundColor: Colors.blue,
        ),
        icon: Icon(icon, color: Colors.white),
        label: Text(label, style: TextStyle(color: Colors.white, fontSize: 16)),
        onPressed: onTap,
      ),
    );
  }
}
