import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'change_password_screen.dart';
import 'main_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_pengajuan_screen.dart';
import 'admin_pendaftaran_screen.dart';
import 'agent_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool isLoading = false;
  String? errorMessage;
  bool isPasswordVisible = false;

  Future<void> login() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = userCredential.user;

      if (user == null) {
        setState(() {
          errorMessage = "Terjadi kesalahan. Coba lagi.";
        });
        return;
      }

      // Cek verifikasi email
      await user.reload(); // refresh user data
      if (!user.emailVerified) {
        await user.sendEmailVerification();

        setState(() {
          errorMessage =
              "Silakan verifikasi email terlebih dahulu. Link verifikasi telah dikirim.";
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Link verifikasi telah dikirim ke email kamu."),
          ),
        );

        await _auth.signOut();
        return;
      }

      // Ambil role dari Firestore
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (!doc.exists) {
        setState(() {
          errorMessage = "Akun belum terdaftar di sistem.";
        });
        await _auth.signOut();
        return;
      }

      final role = doc.data()!['role'];

      if (role == 'supervisor') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainPage()),
        );
      } else if (role == 'admin_pengajuan') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AdminPengajuanScreen()),
        );
      } else if (role == 'admin_pendaftaran') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AdminPendaftaranScreen()),
        );
      } else if (role == 'agent') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AgentScreen()),
        );
      } else {
        setState(() {
          errorMessage = "Role tidak dikenali.";
        });
        await _auth.signOut();
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message;
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Login")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: "Email"),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: "Password",
                suffixIcon: GestureDetector(
                  onLongPress: () {
                    setState(() {
                      isPasswordVisible = true;
                    });
                  },
                  onLongPressUp: () {
                    setState(() {
                      isPasswordVisible = false;
                    });
                  },
                  child: Icon(
                    isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
              obscureText: !isPasswordVisible,
            ),
            if (errorMessage != null) ...[
              SizedBox(height: 10),
              Text(errorMessage!, style: TextStyle(color: Colors.red)),
            ],
            SizedBox(height: 20),
            isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(onPressed: login, child: Text("Login")),
            SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChangePasswordScreen(),
                    ),
                  );
                },
                child: Text("Ganti Password?"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
