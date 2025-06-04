import 'package:flutter/material.dart';

class StatusSavedPendaftaranScreen extends StatelessWidget {
  final String status;
  const StatusSavedPendaftaranScreen({required this.status});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Status: $status")),
      body: Center(child: Text('Tampilkan data untuk status: $status')),
    );
  }
}
