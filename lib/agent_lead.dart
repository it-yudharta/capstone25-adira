import 'package:flutter/material.dart';

class AgentLead extends StatelessWidget {
  const AgentLead({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF0F4F5),
      body: Center(
        child: Text(
          'Lead Screen (Agent)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
