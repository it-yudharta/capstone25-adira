import 'package:flutter/material.dart';

class ResetPasswordAgentScreen extends StatelessWidget {
  const ResetPasswordAgentScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password Agent'),
        backgroundColor: Color(0xFF0E5C36),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text(
          'Halaman Reset Password Agent',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
