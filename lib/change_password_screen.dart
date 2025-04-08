import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ChangePasswordScreen extends StatefulWidget {
  @override
  _ChangePasswordScreenState createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController emailController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool isLoading = false;
  String? errorMessage;
  String? successMessage;

  Future<void> sendPasswordResetEmail() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      successMessage = null;
    });

    try {
      String email = emailController.text.trim();

      if (email.isEmpty) {
        throw FirebaseAuthException(
          code: 'invalid-email',
          message: 'Masukkan email yang valid.',
        );
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
      appBar: AppBar(title: Text("Reset Password")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: "Email"),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 20),
            if (errorMessage != null) ...[
              Text(errorMessage!, style: TextStyle(color: Colors.red)),
              SizedBox(height: 10),
            ],
            if (successMessage != null) ...[
              Text(successMessage!, style: TextStyle(color: Colors.green)),
              SizedBox(height: 10),
            ],
            isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                  onPressed: sendPasswordResetEmail,
                  child: Text("Kirim Email Reset Password"),
                ),
          ],
        ),
      ),
    );
  }
}
