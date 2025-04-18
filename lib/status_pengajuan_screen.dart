import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class StatusPengajuanScreen extends StatelessWidget {
  final String status;
  final String title;

  const StatusPengajuanScreen({
    Key? key,
    required this.status,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final DatabaseReference dbRef = FirebaseDatabase.instance.ref().child(
      'pengajuan',
    );

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: StreamBuilder<DatabaseEvent>(
        stream: dbRef.orderByChild('status').equalTo(status).onValue,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            final Map<dynamic, dynamic> data =
                snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
            final List<Map<dynamic, dynamic>> items = [];

            data.forEach((key, value) {
              final Map<dynamic, dynamic> item = Map<dynamic, dynamic>.from(
                value,
              );
              item['key'] = key;
              items.add(item);
            });

            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final pengajuan = items[index];
                return Card(
                  child: ListTile(
                    title: Text(pengajuan['nama'] ?? 'Tanpa Nama'),
                    subtitle: Text('Status: ${pengajuan['status']}'),
                    trailing: Text(pengajuan['tanggal'] ?? ''),
                    onTap: () {
                      // Aksi ketika item diklik, bisa tambahkan navigasi ke detail
                    },
                  ),
                );
              },
            );
          } else if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else {
            return const Center(child: Text('Tidak ada data.'));
          }
        },
      ),
    );
  }
}
