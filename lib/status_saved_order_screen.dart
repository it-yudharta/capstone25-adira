import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'order_detail_screen.dart';

class StatusSavedOrderScreen extends StatefulWidget {
  final String status;
  final String title;

  const StatusSavedOrderScreen({
    Key? key,
    required this.status,
    required this.title,
  }) : super(key: key);

  @override
  _StatusSavedOrderScreenState createState() => _StatusSavedOrderScreenState();
}

class _StatusSavedOrderScreenState extends State<StatusSavedOrderScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref().child(
    'orders',
  );
  List<Map<dynamic, dynamic>> _filteredOrders = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchFilteredOrders();
  }

  void _fetchFilteredOrders() async {
    setState(() => _isLoading = true);

    final snapshot = await _database.get();
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      final List<Map<dynamic, dynamic>> loaded = [];

      data.forEach((key, value) {
        if (value['lead'] == true && value['status'] == widget.status) {
          value['key'] = key;
          loaded.add(value);
        }
      });

      setState(() {
        _filteredOrders = loaded;
        _isLoading = false;
      });
    } else {
      setState(() {
        _filteredOrders = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF0F4F5),
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Color(0xFFF0F4F5),
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _filteredOrders.isEmpty
              ? Center(
                child: Text(
                  "Tidak ada order tersimpan dengan status '${widget.status}'",
                ),
              )
              : ListView.builder(
                itemCount: _filteredOrders.length,
                itemBuilder: (context, index) {
                  final order = _filteredOrders[index];
                  return _buildOrderCard(order);
                },
              ),
    );
  }

  Widget _buildOrderCard(Map order) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) =>
                    OrderDetailScreen(orderData: order, orderKey: order['key']),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Agent         : ${order['agentName'] ?? '-'}",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text("Nama         : ${order['name'] ?? '-'}"),
                  Text("Alamat       : ${order['domicile'] ?? '-'}"),
                  Text("No. Telp     : ${order['phone'] ?? '-'}"),
                  Text("Pekerjaan    : ${order['job'] ?? '-'}"),
                  Text("Pengajuan    : ${order['installment'] ?? '-'}"),
                  SizedBox(height: 8),
                  Text(
                    "Status        : ${order['status'] ?? 'Belum diproses'}",
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Icon(Icons.bookmark, size: 24, color: Colors.orange),
            ),
          ],
        ),
      ),
    );
  }
}
