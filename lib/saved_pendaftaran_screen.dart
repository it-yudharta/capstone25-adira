import 'package:flutter/material.dart';

class SavedPendaftaranScreen extends StatelessWidget {
  final List<Map<String, String>> dummyPendaftaran = [
    {'nama': 'Andi Saputra', 'tanggal': '2025-05-20'},
    {'nama': 'Budi Hartono', 'tanggal': '2025-05-21'},
    {'nama': 'Citra Dewi', 'tanggal': '2025-05-22'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F5),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pendaftaran Tersimpan',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: dummyPendaftaran.length,
                itemBuilder: (context, index) {
                  final data = dummyPendaftaran[index];
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    child: ListTile(
                      leading: const Icon(
                        Icons.person,
                        color: Color(0xFF0E5C36),
                      ),
                      title: Text(data['nama'] ?? ''),
                      subtitle: Text('Tanggal: ${data['tanggal']}'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
