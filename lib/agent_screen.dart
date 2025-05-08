import 'package:flutter/material.dart';

class AgentScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Agent')),
      body: Center(
        child: Text('Selamat datang, Agent!', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
