import 'package:flutter/material.dart';

class StatusSupervisorPendaftaran extends StatelessWidget {
  final String status;

  const StatusSupervisorPendaftaran({Key? key, required this.status})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Status: $status')),
      body: Center(child: Text('Status Supervisor: $status')),
    );
  }
}
