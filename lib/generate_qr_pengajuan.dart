import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui' as ui;
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
  TextEditingController passwordController = TextEditingController();

  String currentAgentData = "";
  String generatedPassword = "";
  bool isAccountCreated = false;
  bool isAgentNameValid = true;
  bool isEmailValid = true;
  bool isPhoneValid = true;

  @override
  void initState() {
    super.initState();
    agentNameController.addListener(_resetOnEdit);
    emailController.addListener(_resetOnEdit);
    phoneController.addListener(_resetOnEdit);
    passwordController.addListener(_resetOnEdit);
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

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
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

  @override
  void dispose() {
    agentNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _onGeneratePressed() async {
    String name = agentNameController.text.trim();
    String email = emailController.text.trim();
    String phone = phoneController.text.trim();
    setState(() {
      isAgentNameValid = name.isNotEmpty;
      isEmailValid = email.isNotEmpty && isValidEmail(email);
      isPhoneValid = phone.isNotEmpty && isValidPhoneNumber(phone);
    });

    if (!isAgentNameValid || !isEmailValid || !isPhoneValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Mohon isi semua field dengan benar")),
      );
      return;
    }

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

  // Fungsi untuk render QR + email + password jadi image Uint8List
  Future<Uint8List> _captureQrWithText() async {
    // Dapatkan boundary QR original
    RenderRepaintBoundary boundary =
        _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

    // Render QR image asli sebagai ui.Image
    ui.Image qrImage = await boundary.toImage(pixelRatio: 3.0);

    // Tentukan ukuran canvas baru:
    // Tinggi canvas = tinggi QR + tinggi area teks (misal 80)
    int width = qrImage.width;
    int height = qrImage.height + 80;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );

    // Background putih
    final paint = Paint()..color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      paint,
    );

    // Gambar QR code di posisi atas (0,0)
    canvas.drawImage(qrImage, Offset.zero, Paint());

    // Prepare text painter untuk email dan password
    final textStyle = ui.TextStyle(
      color: ui.Color(0xFF0E5C36),
      fontSize: 20,
      fontWeight: FontWeight.bold,
    );
    final paragraphStyle = ui.ParagraphStyle(textAlign: TextAlign.center);

    // Email
    final emailParagraphBuilder =
        ui.ParagraphBuilder(paragraphStyle)
          ..pushStyle(textStyle)
          ..addText("Email: ${emailController.text}");
    final emailParagraph =
        emailParagraphBuilder.build()
          ..layout(ui.ParagraphConstraints(width: width.toDouble()));

    // Password
    final passParagraphBuilder =
        ui.ParagraphBuilder(paragraphStyle)
          ..pushStyle(textStyle)
          ..addText("Password: $generatedPassword");
    final passParagraph =
        passParagraphBuilder.build()
          ..layout(ui.ParagraphConstraints(width: width.toDouble()));

    // Gambar teks di bawah QR code, misal jarak 10 px dari bawah QR
    canvas.drawParagraph(
      emailParagraph,
      Offset(0, qrImage.height.toDouble() + 5),
    );
    canvas.drawParagraph(
      passParagraph,
      Offset(0, qrImage.height.toDouble() + 35),
    );

    // Selesai gambar
    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  Future<void> _saveQrCode() async {
    try {
      if (currentAgentData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Silakan generate QR terlebih dahulu")),
        );
        return;
      }

      // Gunakan fungsi baru untuk ambil image QR + teks
      Uint8List pngBytes = await _captureQrWithText();

      final result = await platform.invokeMethod("saveFileToDownloads", {
        "fileName":
            "qr_pengajuan_img_${DateTime.now().millisecondsSinceEpoch}.png",
        "bytes": pngBytes,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('QR Code berhasil disimpan ke $result')),
      );

      await Future.delayed(Duration(milliseconds: 500));
      _showQrSavedPopup();
    } catch (e) {
      print("Error saving QR: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan QR Code')));
    }
  }

  void _showGenerateConfirmation() {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Generate QR?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'QR and Account will be generated and Pendaftaran will be moved to “QR Given”.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            backgroundColor: Color(0xFFE67D13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            'Back',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _onGeneratePressed();
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: Color(0xFF0E5C36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            'Confirm',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showQrSavedPopup() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(30),
          child: Container(
            padding: EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/QR_Saved.png',
              width: 150,
              height: 150,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool enabled,
    required bool isValid,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final bool isMini = !enabled;

    return SizedBox(
      height: isMini ? 36 : null,
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        style: TextStyle(fontSize: isMini ? 12 : 16),
        decoration: InputDecoration(
          labelText: isMini ? null : label,
          prefixIcon: Icon(
            icon,
            color: Color(0xFF0E5C36),
            size: isMini ? 16 : 24,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(isMini ? 8 : 12),
          ),
          contentPadding: EdgeInsets.symmetric(
            vertical: isMini ? 6 : 12,
            horizontal: isMini ? 8 : 16,
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: isValid ? Colors.grey : Colors.red),
            borderRadius: BorderRadius.circular(isMini ? 8 : 12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF0E5C36), width: 2),
            borderRadius: BorderRadius.circular(isMini ? 8 : 12),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFF0F4F5),
        elevation: 0,
        foregroundColor: Colors.black,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFFF0F4F5),
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        title: Row(
          children: [
            RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(
                    text: 'Fundra',
                    style: TextStyle(color: Color(0xFF0E5C36)),
                  ),
                  TextSpan(
                    text: 'IN',
                    style: TextStyle(color: Color(0xFFE67D13)),
                  ),
                ],
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.black),
              onPressed: _logout,
            ),
          ],
        ),
      ),
      backgroundColor: const Color(0xFFF0F4F5),
      body: Stack(
        children: [
          Positioned.fill(
            bottom: 180,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (currentAgentData.isNotEmpty) ...[
                    Center(
                      child: RepaintBoundary(
                        key: _qrKey,
                        child: Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: Color(0xFF0E5C36),
                              width: 4,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: QrImageView(
                            data: currentAgentData,
                            size: 200,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                  ],
                  if (generatedPassword.isNotEmpty)
                    Column(
                      children: [
                        Container(
                          width: 280,
                          padding: EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Color(0xFF0E5C36)),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(10),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.email,
                                color: Color(0xFF0E5C36),
                                size: 20,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  emailController.text,
                                  style: TextStyle(
                                    color: Color(0xFF0E5C36),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 280,
                          padding: EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Color(0xFF0E5C36)),
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(10),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lock,
                                color: Color(0xFF0E5C36),
                                size: 20,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  generatedPassword,
                                  style: TextStyle(
                                    color: Color(0xFF0E5C36),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                ],
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: const Color(0xFFF0F4F5),
              padding: EdgeInsets.fromLTRB(20, 10, 20, 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMiniTextField(
                    controller: agentNameController,
                    label: "Nama",
                    icon: Icons.person,
                    enabled: !isAccountCreated,
                    isValid: isAgentNameValid,
                  ),
                  SizedBox(height: 10),
                  _buildMiniTextField(
                    controller: emailController,
                    label: "Email",
                    icon: Icons.email,
                    enabled: !isAccountCreated,
                    isValid: isEmailValid,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: 10),
                  _buildMiniTextField(
                    controller: phoneController,
                    label: "No. Telp",
                    icon: Icons.phone,
                    enabled: !isAccountCreated,
                    isValid: isPhoneValid,
                    keyboardType: TextInputType.phone,
                  ),

                  SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              currentAgentData.isEmpty ? null : _saveQrCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF0E5C36),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Align(
                            alignment: Alignment.center,
                            child: Text(
                              "Save QR",
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              isAccountCreated
                                  ? null
                                  : _showGenerateConfirmation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF0E5C36),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Align(
                            alignment: Alignment.center,
                            child: Text(
                              "Generate QR",
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBarPendaftaran(currentRoute: 'qr_agent'),
    );
  }
}
