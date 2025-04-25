import 'dart:typed_data';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:flutter/rendering.dart';

class GenerateQRPendaftaran extends StatefulWidget {
  @override
  _GenerateQRPendaftaranState createState() => _GenerateQRPendaftaranState();
}

class _GenerateQRPendaftaranState extends State<GenerateQRPendaftaran> {
  final GlobalKey _qrKey = GlobalKey();
  final String registrationUrl =
      "https://rionasari.github.io/registration-form/";

  Future<void> _saveQrCode() async {
    try {
      RenderRepaintBoundary boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      var image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/qr_pendaftaran.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(pngBytes);

      // Save ke galeri pakai gal
      await Gal.putImage(imageFile.path);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('QR Code berhasil disimpan ke galeri')),
      );
    } catch (e) {
      print(e);
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
              child: QrImageView(
                data: registrationUrl,
                version: QrVersions.auto,
                size: 250.0,
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
              label: Text("Simpan QR ke Galeri"),
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
