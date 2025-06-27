// ignore_for_file: use_super_parameters, library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'bottom_nav_bar_pendaftaran.dart';
import 'package:url_launcher/url_launcher.dart';

class NotePendaftaranScreen extends StatefulWidget {
  final Map pendaftaran;
  final String pendaftaranKey;

  const NotePendaftaranScreen({
    Key? key,
    required this.pendaftaran,
    required this.pendaftaranKey,
  }) : super(key: key);

  @override
  _NotePendaftaranScreenState createState() => _NotePendaftaranScreenState();
}

class _NotePendaftaranScreenState extends State<NotePendaftaranScreen> {
  late TextEditingController _controller;
  bool _isSaving = false;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.pendaftaran['note']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    final note = _controller.text.trim();

    if (note.isEmpty) {
      setState(() {
        _showError = true;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _showError = false;
    });

    final dbRef = FirebaseDatabase.instance
        .ref()
        .child('agent-form')
        .child(widget.pendaftaranKey);

    await dbRef.update({
      'note': note,
      'status': 'pending',
      'pendingUpdatedAt': DateFormat('dd-MM-yyyy').format(DateTime.now()),
    });

    setState(() => _isSaving = false);
    Navigator.pop(context, note);
  }

  Widget _detailRow(String label, String? value, {VoidCallback? onTap}) {
    final txt = "$label : ${value ?? '-'}";
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child:
          onTap == null
              ? Text(txt, style: TextStyle(fontSize: 14))
              : GestureDetector(
                onTap: onTap,
                child: Text(
                  txt,
                  style: TextStyle(fontSize: 14, color: Colors.blue),
                ),
              ),
    );
  }

  String normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) {
      return '62${digits.substring(1)}';
    } else if (digits.startsWith('62')) {
      return digits;
    } else {
      return '62$digits';
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    final normalized = normalizePhone(phone);
    final uri = Uri.parse('https://wa.me/$normalized');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka WhatsApp')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pendaftaran;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F5),
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: const Color(0xFFF0F4F5),
        elevation: 0,
        foregroundColor: Colors.black,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Color(0xFFF0F4F5),
          statusBarIconBrightness: Brightness.dark,
        ),
        title: Row(
          children: [
            RichText(
              text: TextSpan(
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
            Spacer(),
            IconButton(
              icon: Icon(Icons.logout, color: Colors.black),
              onPressed: () {},
            ),
          ],
        ),
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(
                  child: Text(
                    'Add Note',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Center(
                  child: Text(
                    'Data Pendaftaran',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              child: Container(
                width: double.infinity,
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailRow("Nama", p['fullName']?.toString()),
                    _detailRow("Email", p['email']?.toString()),
                    if (p['phone'] != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: GestureDetector(
                          onTap: () async {
                            try {
                              await _launchWhatsApp(p['phone'].toString());
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error launching WhatsApp: $e'),
                                ),
                              );
                            }
                          },
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                              children: [
                                TextSpan(text: "No. Telp : "),
                                TextSpan(
                                  text: p['phone'],
                                  style: TextStyle(color: Colors.blue),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    _detailRow("Alamat", p['address']?.toString()),
                    _detailRow("Kode Pos", p['postalCode']?.toString()),
                    _detailRow("Status", p['status']?.toString()),
                    if (p['note'] != null && p['note'].toString().isNotEmpty)
                      _detailRow("Existing Note", p['note']?.toString()),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            flex: 1,
            child: Container(
              color: const Color(0xFFF0F4F5),
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Tulis catatan...',
                        hintStyle: TextStyle(
                          color: _showError ? Colors.red : Colors.grey,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color:
                                _showError ? Colors.red : Colors.grey.shade400,
                            width: 1.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color:
                                _showError ? Colors.red : Colors.grey.shade400,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: _showError ? Colors.red : Color(0xFF0E5C36),
                            width: 2,
                          ),
                        ),
                      ),

                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFE67D13),
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveNote,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF0E5C36),
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child:
                              _isSaving
                                  ? CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                  : Text(
                                    'Confirm',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
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
      bottomNavigationBar: BottomNavBarPendaftaran(currentRoute: 'status'),
    );
  }
}
