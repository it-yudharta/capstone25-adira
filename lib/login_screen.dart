// ignore_for_file: use_key_in_widget_constructors, library_private_types_in_public_api, prefer_final_fields, use_build_context_synchronously, avoid_print, sized_box_for_whitespace

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'change_password_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_pengajuan_screen.dart';
import 'admin_pendaftaran_screen.dart';
import 'agent_screen.dart';
import 'main_supervisor.dart';
import 'main_agent.dart';

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
  final _formKey = GlobalKey<FormState>();
  bool _emailError = false;
  bool _passwordError = false;
  bool _emailInvalid = false;
  bool _passwordInvalid = false;

  Future<void> login() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      _emailInvalid = false;
      _passwordInvalid = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/images/rectangle_2.png'), context);
      precacheImage(
        const AssetImage('assets/images/rectangle_10.png'),
        context,
      );
    });
    try {
      if (emailController.text.trim() == 'demo@appkamu.com' &&
          passwordController.text.trim() == 'Demo1234') {
        final userCredential = await _auth.signInWithEmailAndPassword(
          email: 'demo@appkamu.com',
          password: 'Demo1234',
        );

        final user = userCredential.user;

        if (user == null) {
          setState(() {
            errorMessage = "Terjadi kesalahan. Coba lagi.";
          });
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
            MaterialPageRoute(builder: (_) => MainSupervisor()),
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
      } else {
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
        final refreshedUser = _auth.currentUser;
        if (refreshedUser != null && !refreshedUser.emailVerified) {
          await user.sendEmailVerification();

          setState(() {
            isLoading = false;
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
            MaterialPageRoute(builder: (_) => MainSupervisor()),
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
            MaterialPageRoute(builder: (_) => MainAgent()),
          );
        } else {
          setState(() {
            errorMessage = "Role tidak dikenali.";
          });
          await _auth.signOut();
        }
      }
    } on FirebaseAuthException catch (e) {
      print("Firebase error code: ${e.code}");
      print("Firebase error message: ${e.message}");

      setState(() {
        isLoading = false;

        if (e.code == 'user-not-found') {
          _emailInvalid = true;
          _passwordInvalid = false;
        } else if (e.code == 'wrong-password') {
          _passwordInvalid = true;
          _emailInvalid = false;
        } else {
          _emailInvalid = true;
          _passwordInvalid = true;
        }
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
              child: Form(
                key: _formKey,
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

                    TextFormField(
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
                        errorStyle: TextStyle(color: Colors.red),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.red, width: 2),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.red, width: 2),
                        ),
                        errorText:
                            _emailError
                                ? 'Email required'
                                : _emailInvalid
                                ? 'Email wrong'
                                : null,
                      ),

                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email required';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 24),

                    TextFormField(
                      controller: passwordController,
                      obscureText: !isPasswordVisible,
                      cursorColor: Colors.black,
                      style: TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: TextStyle(color: Colors.black),
                        prefixIcon: Icon(Icons.lock, color: Color(0xFF0E5C36)),
                        suffixIcon: GestureDetector(
                          onLongPress:
                              () => setState(() => isPasswordVisible = true),
                          onLongPressUp:
                              () => setState(() => isPasswordVisible = false),
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
                        errorStyle: TextStyle(color: Colors.red),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.red, width: 2),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.red, width: 2),
                        ),
                        errorText:
                            _passwordError
                                ? 'Password required'
                                : _passwordInvalid
                                ? 'Password wrong'
                                : null,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Password required';
                        }
                        return null;
                      },
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
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              login();
                            }
                          },

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
          ),
        ],
      ),
    );
  }
}
