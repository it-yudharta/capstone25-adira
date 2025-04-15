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
  final DatabaseReference _trashRef = FirebaseDatabase.instance.ref().child(
    'trash',
  );

  List<Map<dynamic, dynamic>> _filteredOrders = [];
  List<Map<dynamic, dynamic>> _allOrders = [];
  final List<String> _statusList = [
    'disetujui',
    'ditolak',
    'dibatalkan',
    'diproses',
    'dipending',
  ];

  Set<String> _trashKeys = {};
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchFilteredOrders();
  }

  Future<void> _fetchFilteredOrders() async {
    setState(() {
      _isLoading = true;
    });

    final trashSnapshot = await _trashRef.get();

    if (trashSnapshot.exists) {
      final trashData = trashSnapshot.value as Map<dynamic, dynamic>;
      _trashKeys = trashData.keys.map((e) => e.toString()).toSet();
    } else {
      _trashKeys.clear();
    }

    final snapshot = await _database.get();
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      final List<Map<dynamic, dynamic>> filtered = [];

      data.forEach((key, value) {
        final status = value['status']?.toString().toLowerCase() ?? '';
        if (status == widget.status.toLowerCase() &&
            !_trashKeys.contains(key)) {
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
        _allOrders = filtered;
        _applySearch();
        _isLoading = false;
      });
    } else {
      setState(() {
        _allOrders = [];
        _filteredOrders = [];
        _isLoading = false;
      });
    }
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredOrders = List.from(_allOrders);
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredOrders =
          _allOrders.where((order) {
            final name = (order['name'] ?? '').toString().toLowerCase();
            final email = (order['email'] ?? '').toString().toLowerCase();
            final agentName =
                (order['agentName'] ?? '').toString().toLowerCase();
            return name.contains(query) ||
                email.contains(query) ||
                agentName.contains(query);
          }).toList();
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

  void _confirmDelete(String key, Map order) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text("Pindahkan ke Trash"),
            content: Text(
              "Yakin ingin menghapus data ini? Data akan dipindahkan ke trash.",
            ),
            actions: [
              TextButton(
                child: Text("Batal"),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: Text("Ya, Hapus"),
                onPressed: () async {
                  Navigator.pop(context);
                  final updatedOrder = Map<String, dynamic>.from(order);
                  updatedOrder['key'] = key;
                  await _trashRef.child(key).set(updatedOrder);
                  await _database.child(key).remove();
                  _fetchFilteredOrders();
                },
              ),
            ],
          ),
    );
  }

  void _confirmDeleteAll() {
    if (_filteredOrders.isEmpty) return;

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text("Hapus Semua"),
            content: Text(
              "Yakin ingin memindahkan semua pengajuan berstatus '${widget.status}' ke trash?",
            ),
            actions: [
              TextButton(
                child: Text("Batal"),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: Text("Ya, Hapus Semua"),
                onPressed: () async {
                  Navigator.pop(context);
                  for (final order in _filteredOrders) {
                    final key = order['key'];
                    final updatedOrder = Map<String, dynamic>.from(order);
                    updatedOrder['key'] = key;
                    await _trashRef.child(key).set(updatedOrder);
                    await _database.child(key).remove();
                  }
                  _fetchFilteredOrders();
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
        title: Text(
          'Pengajuan ${widget.status[0].toUpperCase()}${widget.status.substring(1)}',
        ),
        actions: [
          if (_filteredOrders.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep),
              tooltip: "Hapus Semua",
              onPressed: _confirmDeleteAll,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _applySearch();
                });
              },
              decoration: InputDecoration(
                hintText: 'Cari nama/email/agent...',
                prefixIcon: Icon(Icons.search),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                              _applySearch();
                            });
                          },
                        )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _filteredOrders.isEmpty
                    ? Center(
                      child: Text("Belum ada data pengajuan untuk status ini"),
                    )
                    : ListView.builder(
                      itemCount: _filteredOrders.length,
                      itemBuilder: (context, index) {
                        final order = _filteredOrders[index];
                        return _buildOrderCard(order, baseStyle);
                      },
                    ),
          ),
        ],
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
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _showStatusSelector(orderKey),
                          icon: Icon(Icons.edit),
                          label: Text("Ubah Status"),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _confirmDelete(orderKey, order),
                          icon: Icon(Icons.delete),
                          label: Text("Hapus"),
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
