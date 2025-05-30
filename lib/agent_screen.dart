import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';

class AgentScreen extends StatelessWidget {
  const AgentScreen({Key? key}) : super(key: key);

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Agent'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.black),
            onPressed: () => _logout(context),
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black,
      ),
      body: Center(
        child: Text('Selamat datang, Agent!', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
