import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class StatusPengajuanScreen extends StatefulWidget {
  final String status;

  const StatusPengajuanScreen({required this.status});

  @override
  State<StatusPengajuanScreen> createState() => _StatusPengajuanScreenState();
}

class _StatusPengajuanScreenState extends State<StatusPengajuanScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref().child(
    'orders',
  );
  List<Map<dynamic, dynamic>> _filteredOrders = [];
  final List<String> _statusList = [
    'disetujui',
    'ditolak',
    'dibatalkan',
    'diproses',
    'dipending',
  ];

  @override
  void initState() {
    super.initState();
    _fetchFilteredOrders();
  }

  void _fetchFilteredOrders() async {
    final snapshot = await _database.get();
    if (snapshot.exists) {
      final Map<dynamic, dynamic> data =
          snapshot.value as Map<dynamic, dynamic>;
      final List<Map<dynamic, dynamic>> filtered = [];

      data.forEach((key, value) {
        final status = value['status']?.toString().toLowerCase() ?? '';
        if (status == widget.status.toLowerCase()) {
          if (value['timestamp'] != null && value['timestamp'] is int) {
            value['timestamp'] = DateFormat(
              'dd MMM yyyy',
            ).format(DateTime.fromMillisecondsSinceEpoch(value['timestamp']));
          }
          value['key'] = key;
          filtered.add(value);
        }
      });

      setState(() {
        _filteredOrders = filtered;
      });
    }
  }

  void _updateStatus(String key, String newStatus) async {
    await _database.child(key).update({'status': newStatus});
    _fetchFilteredOrders();
  }

  void _showStatusSelector(String key) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children:
                _statusList.map((status) {
                  return ListTile(
                    title: Text(
                      'Rubah ke: ${status[0].toUpperCase()}${status.substring(1)}',
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _updateStatus(key, status);
                    },
                  );
                }).toList(),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle? baseStyle = Theme.of(context).textTheme.bodyMedium;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pengajuan ${widget.status[0].toUpperCase()}${widget.status.substring(1)}',
        ),
      ),
      body:
          _filteredOrders.isEmpty
              ? Center(child: Text("Belum ada data pengajuan untuk status ini"))
              : ListView.builder(
                itemCount: _filteredOrders.length,
                itemBuilder: (context, index) {
                  final order = _filteredOrders[index];
                  return _buildOrderCard(order, baseStyle);
                },
              ),
    );
  }

  Widget _buildOrderCard(Map order, TextStyle? baseStyle) {
    final orderKey = order['key'];

    return Card(
      margin: EdgeInsets.all(10),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ExpansionTile(
          title: DefaultTextStyle.merge(
            style: baseStyle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Nama Pengaju: ${order['name'] ?? '-'}"),
                Text("Email Pengaju: ${order['email'] ?? '-'}"),
                Text("No. Telepon Pengaju: ${order['phone'] ?? '-'}"),
                Text("Nama Agent: ${order['agentName'] ?? '-'}"),
                Text("Email Agent: ${order['agentEmail'] ?? '-'}"),
                Text("No. Telepon Agent: ${order['agentPhone'] ?? '-'}"),
                Text("Status: ${order['status'] ?? '-'}"),
              ],
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: DefaultTextStyle.merge(
                style: baseStyle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Domisili: ${order['domicile'] ?? '-'}"),
                    Text("Kode Pos: ${order['postalCode'] ?? '-'}"),
                    Text("Pekerjaan: ${order['job'] ?? '-'}"),
                    Text("Penghasilan: ${order['income'] ?? '-'}"),
                    Text("Cicilan: ${order['installment'] ?? '-'}"),
                    Text("Jenis Pinjaman: ${order['item'] ?? '-'}"),
                    Text("Tanggal Pengajuan: ${order['timestamp'] ?? '-'}"),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showStatusSelector(orderKey),
                      icon: Icon(Icons.edit),
                      label: Text("Ubah Status"),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
