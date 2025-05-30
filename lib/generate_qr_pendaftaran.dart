import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';

class GenerateQRPendaftaran extends StatefulWidget {
  @override
  _GenerateQRPendaftaranState createState() => _GenerateQRPendaftaranState();
}

class _GenerateQRPendaftaranState extends State<GenerateQRPendaftaran> {
  final GlobalKey _qrKey = GlobalKey();
  static const platform = MethodChannel("com.fundrain.adiraapp/download");

  final String registrationUrl =
      "https://rionasari.github.io/registration-form/";

  Future<void> _saveQrCode() async {
    try {
      RenderRepaintBoundary boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      var image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final result = await platform.invokeMethod("saveFileToDownloads", {
        "fileName":
            "qr_pendaftaran_img_${DateTime.now().millisecondsSinceEpoch}.png",
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
      appBar: AppBar(title: Text('QR Form Pendaftaran')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                color: Colors.white,
                child: QrImageView(
                  data: registrationUrl,
                  version: QrVersions.auto,
                  size: 250.0,
                ),
              ),
            ),

            SizedBox(height: 20),
            Text(
              'Scan QR ini loh ya',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            Spacer(),
            ElevatedButton.icon(
              onPressed: _saveQrCode,
              icon: Icon(Icons.download),
              label: Text("Simpan QR ke Folder Download"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
