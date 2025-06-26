import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';

class AgentQRScreen extends StatefulWidget {
  const AgentQRScreen({Key? key}) : super(key: key);

  @override
  _AgentQRScreenState createState() => _AgentQRScreenState();
}

class _AgentQRScreenState extends State<AgentQRScreen> {
  String? _qrUrl;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  final GlobalKey _qrKey = GlobalKey();
  static const platform = MethodChannel("com.fundrain.adiraapp/download");

  @override
  void initState() {
    super.initState();
    _loadQR();
  }

  Future<void> _loadQR() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        _error = "Belum login";
        _isLoading = false;
      });
      return;
    }

    final email = currentUser.email!;
    final storage = FirebaseStorage.instance;

    try {
      final ListResult result = await storage.ref('qr_codes').listAll();
      final qrFile = result.items.firstWhere(
        (item) => item.name.startsWith(email),
        orElse: () => throw Exception('QR code tidak ditemukan'),
      );
      final url = await qrFile.getDownloadURL();

      setState(() {
        _qrUrl = url;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveQrCode() async {
    if (_qrUrl == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("QR belum tersedia")));
      return;
    }

    setState(() => _isSaving = true);
    _showSavingDialog();

    try {
      final boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      final result = await platform.invokeMethod("saveFileToDownloads", {
        "fileName": "qr_agent_${DateTime.now().millisecondsSinceEpoch}.png",
        "bytes": pngBytes,
      });

      Navigator.of(context).pop(); // Tutup dialog
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('QR Code berhasil disimpan ke $result')),
      );

      await Future.delayed(const Duration(milliseconds: 500));
      _showQrSavedPopup();
    } catch (e) {
      print("Error saving QR: $e");
      Navigator.of(context).pop();
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal menyimpan QR Code')));
    }
  }

  void _showSavingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => const Dialog(
            backgroundColor: Colors.transparent,
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF0E5C36)),
            ),
          ),
    );
  }

  void _showQrSavedPopup() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (_) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(30),
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
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
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F5),
      body: Center(
        child:
            _isLoading
                ? const CircularProgressIndicator(color: Color(0xFF0E5C36))
                : _error != null
                ? Text(
                  "Error: $_error",
                  style: const TextStyle(color: Colors.red),
                )
                : _qrUrl != null
                ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "QR Code Agent",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 20),
                    RepaintBoundary(
                      key: _qrKey,
                      child: Image.network(
                        _qrUrl!,
                        width: 300,
                        height: 300,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0E5C36),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _saveQrCode,
                      child: const Text(
                        "Save QR Code",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                )
                : const Text("QR code tidak ditemukan"),
      ),
    );
  }
}
