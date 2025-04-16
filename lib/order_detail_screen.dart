import 'package:flutter/material.dart';

class OrderDetailScreen extends StatelessWidget {
  final Map<dynamic, dynamic> orderData;
  final String orderKey;

  const OrderDetailScreen({
    Key? key,
    required this.orderData,
    required this.orderKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String getField(String field) => orderData[field] ?? '-';

    return Scaffold(
      appBar: AppBar(title: Text('Detail Pengajuan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Nama Pengaju: ${getField('name')}"),
            Text("Email Pengaju: ${getField('email')}"),
            Text("No. Telepon Pengaju: ${getField('phone')}"),
            SizedBox(height: 8),
            Text("Nama Agent: ${getField('agentName')}"),
            Text("Email Agent: ${getField('agentEmail')}"),
            Text("No. Telepon Agent: ${getField('agentPhone')}"),
            SizedBox(height: 8),
            Text("Status: ${getField('status')}"),
            Text("Domisili: ${getField('domicile')}"),
            Text("Kode Pos: ${getField('postalCode')}"),
            Text("Pekerjaan: ${getField('job')}"),
            Text("Penghasilan: ${getField('income')}"),
            Text("Cicilan: ${getField('installment')}"),
            Text("Jenis Pinjaman: ${getField('item')}"),
            Text("Tanggal Pengajuan: ${getField('timestamp')}"),
            SizedBox(height: 20),
            ElevatedButton.icon(
              icon: Icon(Icons.edit),
              label: Text("Ubah Status"),
              onPressed: () {
                Navigator.pop(context, orderKey); // kirim kembali orderKey
              },
            ),
          ],
        ),
      ),
    );
  }
}
