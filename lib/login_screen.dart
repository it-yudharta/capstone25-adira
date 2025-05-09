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

      await user.reload();
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
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: -28,
            child: Container(
              width: 300,
              height: 300,
              child: Image.asset(
                'assets/images/rectangle_2.png',
                fit: BoxFit.cover,
              ),
            ),
          ),

          Positioned(
            top: 0,
            left: -10,
            child: Container(
              width: 215,
              height: 215,
              child: Image.asset(
                'assets/images/rectangle_10.png',
                fit: BoxFit.cover,
              ),
            ),
          ),

          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 250, 16, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    text: TextSpan(
                      text: 'Fundra',
                      style: TextStyle(
                        color: Color(0xFF0E5C36),
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                      children: [
                        TextSpan(
                          text: 'IN',
                          style: TextStyle(
                            color: Color(0xFFE67D13),
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 40),

                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    cursorColor: Colors.black,
                    style: TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(color: Colors.black),
                      prefixIcon: Icon(Icons.email, color: Color(0xFF0E5C36)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Color(0xFF0E5C36),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),

                  TextField(
                    controller: passwordController,
                    obscureText: !isPasswordVisible,
                    cursorColor: Colors.black,
                    style: TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(color: Colors.black),
                      prefixIcon: Icon(Icons.lock, color: Color(0xFF0E5C36)),

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
                          isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.black,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Color(0xFF0E5C36),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChangePasswordScreen(),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black,
                      ),
                      child: Text("Forgot Password?"),
                    ),
                  ),

                  if (errorMessage != null) ...[
                    SizedBox(height: 10),
                    Text(errorMessage!, style: TextStyle(color: Colors.red)),
                  ],

                  SizedBox(height: 20),

                  isLoading
                      ? CircularProgressIndicator()
                      : ElevatedButton(
                        onPressed: login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF0E5C36),
                          foregroundColor: Colors.white,
                          minimumSize: Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          "Login",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
