import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'custom_bottom_nav_bar.dart';

class NotePengajuanScreen extends StatefulWidget {
  final Map orderData;
  final String orderKey;

  const NotePengajuanScreen({
    Key? key,
    required this.orderData,
    required this.orderKey,
  }) : super(key: key);

  @override
  _NotePengajuanScreenState createState() => _NotePengajuanScreenState();
}

class _NotePengajuanScreenState extends State<NotePengajuanScreen> {
  late TextEditingController _controller;
  bool _isSaving = false;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.orderData['note']?.toString() ?? '',
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
      setState(() => _showError = true);
      return;
    }

    setState(() {
      _isSaving = true;
      _showError = false;
    });

    final dbRef = FirebaseDatabase.instance
        .ref()
        .child('orders')
        .child(widget.orderKey);

    await dbRef.update({
      'note': note,
      'status': 'pending',
      'pendingUpdatedAt': DateFormat('dd-MM-yyyy').format(DateTime.now()),
    });

    setState(() => _isSaving = false);
    Navigator.pop(context, note);
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

  Widget _detailRow(String label, String? value, {VoidCallback? onTap}) {
    final text = "$label : ${value ?? '-'}";
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child:
          onTap == null
              ? Text(text, style: const TextStyle(fontSize: 14))
              : GestureDetector(
                onTap: onTap,
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 14, color: Colors.blue),
                ),
              ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.orderData;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F5),
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: const Color(0xFFF0F4F5),
        elevation: 0,
        foregroundColor: Colors.black,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFFF0F4F5),
          statusBarIconBrightness: Brightness.dark,
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
                    'Data Pengajuan',
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
            child: SingleChildScrollView(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
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
                    _detailRow("Agent", o['agentName']?.toString()),
                    _detailRow("Nama", o['name']?.toString()),
                    _detailRow("Alamat", o['domicile']?.toString()),
                    if (o['phone'] != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: GestureDetector(
                          onTap: () => _launchWhatsApp(o['phone'].toString()),
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                              children: [
                                const TextSpan(text: "No. Telp : "),
                                TextSpan(
                                  text: o['phone'].toString(),
                                  style: const TextStyle(color: Colors.blue),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    _detailRow("Pekerjaan", o['job']?.toString()),
                    _detailRow("Pengajuan", o['installment']?.toString()),
                    _detailRow("Status", o['status']?.toString()),
                    if (o['note'] != null && o['note'].toString().isNotEmpty)
                      _detailRow("Existing Note", o['note']?.toString()),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: Container(
              color: const Color(0xFFF0F4F5),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                            color:
                                _showError
                                    ? Colors.red
                                    : const Color(0xFF0E5C36),
                            width: 2,
                          ),
                        ),
                      ),
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFE67D13),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveNote,
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFF0E5C36),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child:
                              _isSaving
                                  ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                  : const Text(
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
      bottomNavigationBar: const CustomBottomNavBar(currentRoute: 'other'),
    );
  }
}
