import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class GenerateQRPengajuan extends StatefulWidget {
  @override
  _GenerateQRPengajuanState createState() => _GenerateQRPengajuanState();
}

class _GenerateQRPengajuanState extends State<GenerateQRPengajuan> {
  TextEditingController agentNameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  GlobalKey globalKey = GlobalKey();
  String currentAgentData = "";

  bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  bool isValidPhoneNumber(String phone) {
    final phoneRegex = RegExp(r'^[0-9]+$');
    return phoneRegex.hasMatch(phone);
  }

  Future<void> _saveQRCode() async {
    try {
      if (currentAgentData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Silakan generate QR terlebih dahulu")),
        );
        return;
      }

      await Future.delayed(Duration(milliseconds: 500));

      RenderRepaintBoundary? boundary =
          globalKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        print("RenderRepaintBoundary null");
        return;
      }

      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) {
        print("Gagal mengonversi gambar ke byte data");
        return;
      }

      Uint8List pngBytes = byteData.buffer.asUint8List();

      final success = await saveImageToGallery(pngBytes);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("QR Code berhasil disimpan ke Galeri!")),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal menyimpan QR Code")));
      }
    } catch (e) {
      print("Error saat menyimpan QR: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<bool> saveImageToGallery(Uint8List bytes) async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) return false;

      final qrDir = Directory('${directory.path}/QRCodes');
      if (!(await qrDir.exists())) {
        await qrDir.create(recursive: true);
      }

      final filePath =
          '${qrDir.path}/QR${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      return true;
    } catch (e) {
      print("Error saat menyimpan: $e");
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Generate QR for Pengajuan')),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
                onPressed: () {
                  String name = agentNameController.text.trim();
                  String email = emailController.text.trim();
                  String phone = phoneController.text.trim();

                  if (!isValidEmail(email)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Masukkan email yang valid")),
                    );
                    return;
                  }

                  if (!isValidPhoneNumber(phone)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Nomor telepon hanya boleh berisi angka"),
                      ),
                    );
                    return;
                  }

                  setState(() {
                    currentAgentData =
                        "https://rionasari.github.io/reseller-form/?agentName=$name&agentEmail=$email&agentPhone=$phone";
                  });
                },
                child: Text("Generate QR Code"),
              ),
              SizedBox(height: 20),
              if (currentAgentData.isNotEmpty)
                RepaintBoundary(
                  key: globalKey,
                  child: Container(
                    color: Colors.white,
                    padding: EdgeInsets.all(10),
                    child: QrImageView(
                      data: currentAgentData,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: currentAgentData.isEmpty ? null : _saveQRCode,
                child: Text("Simpan ke Galeri"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
