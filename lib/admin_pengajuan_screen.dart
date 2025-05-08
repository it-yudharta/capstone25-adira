import 'package:flutter/material.dart';

class AdminPengajuanScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Admin Pengajuan')),
      body: Center(
        child: Text(
          'Selamat datang, Admin Pengajuan!',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
