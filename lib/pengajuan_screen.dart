import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'status_pengajuan_screen.dart';
import 'trash_screen.dart';

class PengajuanScreen extends StatefulWidget {
  @override
  _PengajuanScreenState createState() => _PengajuanScreenState();
}

class _PengajuanScreenState extends State<PengajuanScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref().child(
    'orders',
  );
  final TextEditingController _searchController = TextEditingController();

  List<Map<dynamic, dynamic>> _orders = [];
  List<Map<dynamic, dynamic>> _filteredOrders = [];
  String _searchQuery = '';
  bool _isLoading = false; // ✅ Tambahkan indikator loading

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
    setState(() => _isLoading = true); // ✅ Mulai loading

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
        _applySearch();
        _isLoading = false; // ✅ Selesai loading
      });
    } else {
      setState(() {
        _orders = [];
        _filteredOrders = [];
        _isLoading = false; // ✅ Selesai loading walau kosong
      });
    }
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredOrders = List.from(_orders);
    } else {
      _filteredOrders =
          _orders.where((order) {
            final name = (order['name'] ?? '').toString().toLowerCase();
            final email = (order['email'] ?? '').toString().toLowerCase();
            final agentName =
                (order['agentName'] ?? '').toString().toLowerCase();
            final query = _searchQuery.toLowerCase();
            return name.contains(query) ||
                email.contains(query) ||
                agentName.contains(query);
          }).toList();
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

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _applySearch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle? baseStyle = Theme.of(context).textTheme.bodyMedium;

    return Scaffold(
      appBar: AppBar(
        title: Text('Pengajuan'),
        actions: [
          Container(
            width: 200,
            padding: EdgeInsets.symmetric(vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _applySearch();
                });
              },
              decoration: InputDecoration(
                hintText: 'Cari...',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 0,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                fillColor: Colors.white,
                filled: true,
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: _clearSearch,
                        )
                        : null,
              ),
              style: TextStyle(fontSize: 14),
            ),
          ),
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
                _isLoading
                    ? Center(
                      child: CircularProgressIndicator(),
                    ) // ✅ Loading saat fetch data
                    : _orders.isEmpty
                    ? Center(child: Text("Tidak ada pengajuan baru"))
                    : _filteredOrders.isEmpty
                    ? Center(
                      child: Text(
                        "Tidak ada pengajuan yang cocok dengan pencarian ini",
                      ),
                    )
                    : ListView.builder(
                      itemCount: _filteredOrders.length,
                      itemBuilder: (context, index) {
                        final order = _filteredOrders[index];
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
