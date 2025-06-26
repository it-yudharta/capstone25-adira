// ignore_for_file: use_super_parameters, library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ResetPasswordAgentScreen extends StatefulWidget {
  const ResetPasswordAgentScreen({Key? key}) : super(key: key);

  @override
  _ResetPasswordAgentScreenState createState() =>
      _ResetPasswordAgentScreenState();
}

class _ResetPasswordAgentScreenState extends State<ResetPasswordAgentScreen> {
  final TextEditingController emailController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  final FocusNode _emailFocus = FocusNode();

  bool isLoading = false;
  String? errorMessage;
  String? successMessage;
  bool _emailError = false;
  bool _emailInvalid = false;

  Future<void> sendPasswordResetEmail() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      successMessage = null;
      _emailError = false;
      _emailInvalid = false;
    });

    try {
      String email = emailController.text.trim();

      if (email.isEmpty) {
        setState(() => _emailError = true);
        throw FirebaseAuthException(code: 'empty-email');
      }

      await _auth.sendPasswordResetEmail(email: email);

      setState(() {
        successMessage = "Silahkan cek email untuk mengganti password.";
      });

      Fluttertoast.showToast(
        msg: "Cek email untuk mengatur ulang password.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        setState(() => _emailInvalid = true);
      } else if (e.code == 'empty-email') {
        setState(() => _emailError = true);
      } else {
        setState(() => errorMessage = e.message);
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    _emailFocus.dispose();
    super.dispose();
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
            child: SizedBox(
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
            child: SizedBox(
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
                    Text(
                      'Reset Password?',
                      style: TextStyle(
                        color: Color(0xFF0E5C36),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      "Please enter your email address. You will receive a link to create a new password via email.",
                      style: TextStyle(fontSize: 14, color: Colors.green),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailController,
                      focusNode: _emailFocus,
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
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: Icon(Icons.arrow_back, color: Colors.black),
                        label: Text(
                          "Back to view data pengajuan",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (errorMessage != null) ...[
                      Text(errorMessage!, style: TextStyle(color: Colors.red)),
                      const SizedBox(height: 10),
                    ],
                    if (successMessage != null) ...[
                      Text(
                        successMessage!,
                        style: TextStyle(color: Colors.green),
                      ),
                      const SizedBox(height: 10),
                    ],
                    isLoading
                        ? CircularProgressIndicator()
                        : ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              sendPasswordResetEmail();
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
                            "Send",
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
