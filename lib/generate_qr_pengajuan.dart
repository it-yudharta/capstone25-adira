import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'bottom_nav_bar_pendaftaran.dart';

class GenerateQRPengajuan extends StatefulWidget {
  @override
  _GenerateQRPengajuanState createState() => _GenerateQRPengajuanState();
}

class _GenerateQRPengajuanState extends State<GenerateQRPengajuan> {
  final GlobalKey _qrKey = GlobalKey();
  static const platform = MethodChannel("com.fundrain.adiraapp/download");

  TextEditingController agentNameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController phoneController = TextEditingController();

  String currentAgentData = "";
  String generatedPassword = "";
  bool isAccountCreated = false;

  @override
  void initState() {
    super.initState();
    agentNameController.addListener(_resetOnEdit);
    emailController.addListener(_resetOnEdit);
    phoneController.addListener(_resetOnEdit);
  }

  void _resetOnEdit() {
    if (isAccountCreated) {
      setState(() {
        currentAgentData = "";
        generatedPassword = "";
        isAccountCreated = false;
      });
    }
  }

  bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  bool isValidPhoneNumber(String phone) {
    final phoneRegex = RegExp(r'^[0-9]+$');
    return phoneRegex.hasMatch(phone);
  }

  String _generateRandomPassword(String email) {
    String prefix = email.length >= 3 ? email.substring(0, 3) : email;
    int randomNum = DateTime.now().millisecondsSinceEpoch % 1000;
    return "$prefix$randomNum";
  }

  Future<void> _createAgentAccount({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    UserCredential userCredential = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await firestore.collection('users').doc(userCredential.user!.uid).set({
      'name': name,
      'email': email,
      'phone': phone,
      'role': 'agent',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _onGeneratePressed() async {
    String name = agentNameController.text.trim();
    String email = emailController.text.trim();
    String phone = phoneController.text.trim();

    if (!isValidEmail(email)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Masukkan email yang valid")));
      return;
    }

    if (!isValidPhoneNumber(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Nomor telepon hanya boleh berisi angka")),
      );
      return;
    }

    String password = _generateRandomPassword(email);

    try {
      await _createAgentAccount(
        name: name,
        email: email,
        phone: phone,
        password: password,
      );

      setState(() {
        generatedPassword = password;
        currentAgentData =
            "https://rionasari.github.io/reseller-form/?agentName=$name&agentEmail=$email&agentPhone=$phone&agentPass=$password";
        isAccountCreated = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Akun agent berhasil dibuat! Password: $password"),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message = "Gagal membuat akun agent";
      if (e.code == 'email-already-in-use') {
        message = "Email sudah digunakan oleh akun lain.";
      } else if (e.code == 'invalid-email') {
        message = "Format email tidak valid.";
      } else if (e.code == 'weak-password') {
        message = "Password terlalu lemah.";
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      print("Error create agent account: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal membuat akun agent")));
    }
  }

  Future<void> _saveQrCode() async {
    try {
      if (currentAgentData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Silakan generate QR terlebih dahulu")),
        );
        return;
      }

      RenderRepaintBoundary boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      var image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final result = await platform.invokeMethod("saveFileToDownloads", {
        "fileName":
            "qr_pengajuan_img_${DateTime.now().millisecondsSinceEpoch}.png",
        "bytes": pngBytes,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('QR Code berhasil disimpan ke $result')),
      );
    } catch (e) {
      print("Error saving QR: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan QR Code')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Generate QR Agent'),
        backgroundColor: const Color(0xFFF0F4F5),
        elevation: 0,
        foregroundColor: Colors.black,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Color(0xFFF0F4F5),
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      backgroundColor: const Color(0xFFF0F4F5),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: agentNameController,
              decoration: InputDecoration(
                labelText: "Masukkan Nama Agent",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: "Masukkan Email Agent",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 10),
            TextField(
              controller: phoneController,
              decoration: InputDecoration(
                labelText: "Masukkan Nomor Telepon Agent",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _onGeneratePressed,
              child: Text("Generate QR Code & Buat Akun"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0E5C36),
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 20),
            if (currentAgentData.isNotEmpty)
              RepaintBoundary(
                key: _qrKey,
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Color(0xFF0E5C36), width: 4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: QrImageView(
                    data: currentAgentData,
                    size: 250,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            SizedBox(height: 20),
            if (generatedPassword.isNotEmpty)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green),
                ),
                child: Text(
                  "Password agent sementara:\n$generatedPassword",
                  style: TextStyle(
                    color: Colors.green[900],
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: currentAgentData.isEmpty ? null : _saveQrCode,
              child: Text("Save QR Code"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0E5C36),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                textStyle: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: BottomNavBarPendaftaran(currentRoute: 'qr_agent'),
    );
  }
}
