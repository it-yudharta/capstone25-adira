import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'status_pengajuan_screen.dart';
import 'trash_screen.dart'; // ✅ Tambahkan import

class PengajuanScreen extends StatefulWidget {
  @override
  _PengajuanScreenState createState() => _PengajuanScreenState();
}

class _PengajuanScreenState extends State<PengajuanScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref().child(
    'orders',
  );
  List<Map<dynamic, dynamic>> _orders = [];

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
    _fetchOrders();
  }

  void _fetchOrders() async {
    final snapshot = await _database.get();
    if (snapshot.exists) {
      final Map<dynamic, dynamic> data =
          snapshot.value as Map<dynamic, dynamic>;
      final List<Map<dynamic, dynamic>> loadedOrders = [];

      data.forEach((key, value) {
        final status = value['status']?.toString().toLowerCase() ?? '';
        if (status.isEmpty || status == 'belum diproses') {
          if (value['timestamp'] != null && value['timestamp'] is int) {
            value['timestamp'] = _convertTimestamp(value['timestamp']);
          }
          value['key'] = key;
          loadedOrders.add(value);
        }
      });

      setState(() {
        _orders = loadedOrders;
      });
    } else {
      setState(() {
        _orders = [];
      });
    }
  }

  String _convertTimestamp(int timestamp) {
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('dd MMM yyyy').format(dateTime);
  }

  void _updateStatus(String key, String newStatus) async {
    await _database.child(key).update({'status': newStatus});
    _fetchOrders();
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
                      'Setel ke: ${status[0].toUpperCase()}${status.substring(1)}',
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

  void _navigateToStatusScreen(String status) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StatusPengajuanScreen(status: status)),
    );
  }

  void _navigateToTrashScreen() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => TrashScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle? baseStyle = Theme.of(context).textTheme.bodyMedium;

    return Scaffold(
      appBar: AppBar(
        title: Text('Pengajuan'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            tooltip: "Lihat Trash",
            onPressed: _navigateToTrashScreen,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child:
                _orders.isEmpty
                    ? Center(child: Text("Tidak ada pengajuan baru"))
                    : ListView.builder(
                      itemCount: _orders.length,
                      itemBuilder: (context, index) {
                        final order = _orders[index];
                        final orderKey = order['key'];
                        return _buildOrderCard(order, orderKey, baseStyle);
                      },
                    ),
          ),
          Container(
            color: Colors.grey.shade100,
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Wrap(
              alignment: WrapAlignment.spaceEvenly,
              spacing: 8,
              runSpacing: 8,
              children:
                  _statusList.map((status) {
                    return _buildMenuButton(
                      status[0].toUpperCase() + status.substring(1),
                      Colors.white,
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(String label, Color color) {
    return ElevatedButton(
      onPressed: () => _navigateToStatusScreen(label.toLowerCase()),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text('Pengajuan $label'),
    );
  }

  Widget _buildOrderCard(Map order, String orderKey, TextStyle? baseStyle) {
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
                Text("Status: ${order['status'] ?? 'Belum diproses'}"),
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
