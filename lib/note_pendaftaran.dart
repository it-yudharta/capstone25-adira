// lib/widgets/note_pendaftaran.dart

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class NotePendaftaranScreen extends StatefulWidget {
  final String pendaftaranKey;
  final String? initialNote;

  const NotePendaftaranScreen({
    Key? key,
    required this.pendaftaranKey,
    this.initialNote,
  }) : super(key: key);

  @override
  _NotePendaftaranScreenState createState() => _NotePendaftaranScreenState();
}

class _NotePendaftaranScreenState extends State<NotePendaftaranScreen> {
  late TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    final note = _controller.text.trim();
    if (note.isEmpty) return;

    setState(() => _isSaving = true);

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

    // kembali ke halaman sebelumnya dengan membawa note
    Navigator.pop(context, note);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Note'),
        backgroundColor: Color(0xFF0E5C36),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Tulis catatan...',
                  border: OutlineInputBorder(),
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
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
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text('Simpan', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
