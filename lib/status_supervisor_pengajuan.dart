import 'package:flutter/material.dart';

class StatusSupervisorPengajuan extends StatelessWidget {
  final String status;
  final String title;

  const StatusSupervisorPengajuan({
    Key? key,
    required this.status,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('Status: $status')),
    );
  }
}
