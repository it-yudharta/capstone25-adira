import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  final DatabaseReference _trashRef = FirebaseDatabase.instance.ref().child(
    'trash',
  );
  final DatabaseReference _ordersRef = FirebaseDatabase.instance.ref().child(
    'orders',
  );

  List<Map<dynamic, dynamic>> _trashOrders = [];

  @override
  void initState() {
    super.initState();
    _fetchTrashOrders();
  }

  void _fetchTrashOrders() async {
    final snapshot = await _trashRef.get();
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      final List<Map<dynamic, dynamic>> orders = [];

      data.forEach((key, value) {
        value['key'] = key;
        orders.add(value);
      });

      setState(() {
        _trashOrders = orders;
      });
    } else {
      setState(() {
        _trashOrders = [];
      });
    }
  }

  void _confirmRestore(String key, Map order) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text("Kembalikan Pengajuan"),
            content: Text(
              "Yakin ingin mengembalikan data ini ke daftar pengajuan?",
            ),
            actions: [
              TextButton(
                child: Text("Batal"),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: Text("Kembalikan"),
                onPressed: () async {
                  Navigator.pop(context);

                  final restoredOrder = Map<String, dynamic>.from(order);
                  restoredOrder.remove('key'); // Hilangkan key dari isi data

                  // Cek dan ubah timestamp jika masih dalam format string
                  if (restoredOrder['timestamp'] is String) {
                    try {
                      final parsedDate = DateFormat(
                        'dd MMM yyyy',
                      ).parse(restoredOrder['timestamp']);
                      restoredOrder['timestamp'] =
                          parsedDate.millisecondsSinceEpoch;
                    } catch (_) {
                      restoredOrder['timestamp'] =
                          DateTime.now().millisecondsSinceEpoch;
                    }
                  }

                  await _ordersRef.child(key).set(restoredOrder);
                  await _trashRef.child(key).remove();
                  _fetchTrashOrders();
                },
              ),
            ],
          ),
    );
  }

  void _confirmPermanentDelete(String key) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text("Hapus Permanen"),
            content: Text("Data ini akan dihapus secara permanen. Lanjutkan?"),
            actions: [
              TextButton(
                child: Text("Batal"),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: Text("Hapus"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  Navigator.pop(context);
                  await _trashRef.child(key).remove();
                  _fetchTrashOrders();
                },
              ),
            ],
          ),
    );
  }

  void _confirmEmptyTrash() {
    if (_trashOrders.isEmpty) return;

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text("Kosongkan Trash"),
            content: Text(
              "Yakin ingin menghapus semua data di trash secara permanen?",
            ),
            actions: [
              TextButton(
                child: Text("Batal"),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: Text("Hapus Semua"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  Navigator.pop(context);
                  await _trashRef.remove();
                  _fetchTrashOrders();
                },
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle? baseStyle = Theme.of(context).textTheme.bodyMedium;

    return Scaffold(
      appBar: AppBar(
        title: Text("Trash"),
        actions: [
          if (_trashOrders.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_forever),
              tooltip: "Kosongkan Trash",
              onPressed: _confirmEmptyTrash,
            ),
        ],
      ),
      body:
          _trashOrders.isEmpty
              ? Center(child: Text("Trash kosong"))
              : ListView.builder(
                itemCount: _trashOrders.length,
                itemBuilder: (context, index) {
                  final order = _trashOrders[index];
                  return _buildTrashCard(order, baseStyle);
                },
              ),
    );
  }

  Widget _buildTrashCard(Map order, TextStyle? baseStyle) {
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
                Text("Status Terakhir: ${order['status'] ?? '-'}"),
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _confirmRestore(orderKey, order),
                          icon: Icon(Icons.restore),
                          label: Text("Kembalikan"),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _confirmPermanentDelete(orderKey),
                          icon: Icon(Icons.delete_forever),
                          label: Text("Hapus Permanen"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
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
      ),
    );
  }
}
