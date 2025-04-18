import 'package:flutter/material.dart';

class OrderDetailScreen extends StatelessWidget {
  final Map orderData;
  final String orderKey;

  OrderDetailScreen({required this.orderData, required this.orderKey});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Order Detail')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Agent: ${orderData['agentName'] ?? '-'}"),
            Text("Nama: ${orderData['name'] ?? '-'}"),
            Text("Alamat: ${orderData['domicile'] ?? '-'}"),
            Text("No. Telp: ${orderData['phone'] ?? '-'}"),
            Text("Pekerjaan: ${orderData['job'] ?? '-'}"),
            Text("Pengajuan: ${orderData['installment'] ?? '-'}"),
            Text("Status: ${orderData['status'] ?? 'Belum diproses'}"),
            // Add more details as needed
          ],
        ),
      ),
    );
  }
}
