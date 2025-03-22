import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart'; // Ganti gallery_saver dengan gal
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class GenerateQRPengajuan extends StatefulWidget {
  @override
  _GenerateQRPengajuanState createState() => _GenerateQRPengajuanState();
}

class _GenerateQRPengajuanState extends State<GenerateQRPengajuan> {
  TextEditingController resellerNameController = TextEditingController();
  GlobalKey globalKey = GlobalKey();
  String currentResellerName = "";

  Future<void> _saveQRCode() async {
    try {
      if (currentResellerName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Silakan generate QR terlebih dahulu")),
        );
        return;
      }

      await Future.delayed(
        Duration(milliseconds: 500),
      ); // Delay agar gambar terbentuk

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

      // Simpan ke galeri
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
      // Minta izin penyimpanan (hanya diperlukan untuk Android versi lama)
      if (await Permission.storage.request().isDenied) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Izin penyimpanan ditolak")));
        return false;
      }

      // Simpan gambar ke file sementara
      Directory tempDir = await getTemporaryDirectory();
      String filePath =
          '${tempDir.path}/QR_${DateTime.now().millisecondsSinceEpoch}.png';
      File file = File(filePath);
      await file.writeAsBytes(bytes);

      // Simpan ke galeri dengan gal
      await Gal.putImage(file.path, album: "QR Codes");

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
        // Tambahkan scroll agar tidak overflow
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: resellerNameController,
                decoration: InputDecoration(
                  labelText: "Masukkan Nama Reseller",
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    currentResellerName = resellerNameController.text.trim();
                  });
                },
                child: Text("Generate QR Code"),
              ),
              SizedBox(height: 20),
              if (currentResellerName.isNotEmpty)
                RepaintBoundary(
                  key: globalKey,
                  child: Container(
                    color: Colors.white, // Background putih agar tidak hitam
                    padding: EdgeInsets.all(10),
                    child: QrImageView(
                      data:
                          "https://rionasari.github.io/reseller-form/?resellerName=$currentResellerName",
                      size: 200,
                      backgroundColor:
                          Colors.white, // Pastikan QR punya background
                    ),
                  ),
                ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed:
                    currentResellerName.isEmpty
                        ? null
                        : _saveQRCode, // Tombol dinonaktifkan jika QR belum dibuat
                child: Text("Simpan ke Galeri"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
