import 'package:flutter/material.dart';
import 'generate_qr_pengajuan.dart';
import 'generate_qr_pendaftaran.dart';

class GenerateQRScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Generate QR Code'),
      ),
      body: Center(
        child: ListView(
          padding: EdgeInsets.all(20),
          children: [
            MenuButton(
              icon: Icons.qr_code,
              label: "Generate QR for Pengajuan",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GenerateQRPengajuan()),
                );
              },
            ),
            MenuButton(
              icon: Icons.qr_code_2,
              label: "Generate QR for Pendaftaran",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GenerateQRPendaftaran()),
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
