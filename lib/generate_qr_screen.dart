import 'package:flutter/material.dart';
import 'generate_qr_pengajuan.dart';
import 'generate_qr_pendaftaran.dart';

class GenerateQRScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              'QR Code',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Pengajuan & Pendaftaran',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                SizedBox(height: 20),
                Image.asset(
                  'assets/images/Barcode-removebg-preview.png',
                  width: 400,
                  height: 400,
                  fit: BoxFit.contain,
                ),
                SizedBox(height: 30),
                MenuButton(
                  label: "Generate QR Pendaftaran",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GenerateQRPendaftaran(),
                      ),
                    );
                  },
                ),
                SizedBox(height: 20),
                MenuButton(
                  label: "Generate QR Code Agent",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GenerateQRPengajuan(),
                      ),
                    );
                  },
                ),
                SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MenuButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const MenuButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: Size(double.infinity, 50),
        backgroundColor: const Color(0xFF0E5C36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      child: Text(label, style: TextStyle(color: Colors.white, fontSize: 16)),
      onPressed: onTap,
    );
  }
}
