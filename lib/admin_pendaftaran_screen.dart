import 'package:flutter/material.dart';

class AdminPendaftaranScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Admin Pendaftaran')),
      body: Center(
        child: Text(
          'Selamat datang, Admin Pendaftaran!',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
