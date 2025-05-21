import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'order_detail_screen.dart';
import 'custom_bottom_nav_bar.dart';
import 'status_saved_order_screen.dart';

class SavedOrdersScreen extends StatefulWidget {
  @override
  _SavedOrdersScreenState createState() => _SavedOrdersScreenState();
}

class _SavedOrdersScreenState extends State<SavedOrdersScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref().child(
    'orders',
  );
  List<Map<dynamic, dynamic>> _savedOrders = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchSavedOrders();
  }

  void _fetchSavedOrders() async {
    setState(() => _isLoading = true);
    final snapshot = await _database.get();
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      final loadedOrders = <Map<dynamic, dynamic>>[];

      data.forEach((key, value) {
        if (value['lead'] == true) {
          value['key'] = key;
          loadedOrders.add(value);
        }
      });

      setState(() {
        _savedOrders = loadedOrders;
        _isLoading = false;
      });
    } else {
      setState(() {
        _savedOrders = [];
        _isLoading = false;
      });
    }
  }

  Widget _buildStatusMenu() {
    final List<Map<String, dynamic>> statusButtons = [
      {'label': 'Cancel', 'status': 'cancel', 'icon': Icons.cancel},
      {'label': 'Process', 'status': 'process', 'icon': Icons.hourglass_bottom},
      {'label': 'Reject', 'status': 'reject', 'icon': Icons.block},
      {'label': 'Approve', 'status': 'approve', 'icon': Icons.check_circle},
      {'label': 'Trash Bin', 'status': 'trash', 'icon': Icons.delete},
    ];

    return Container(
      margin: EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      padding: EdgeInsets.symmetric(horizontal: 19, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 5)],
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(statusButtons.length * 2 - 1, (index) {
            if (index.isOdd) return SizedBox(width: 16);
            final item = statusButtons[index ~/ 2];
            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => StatusSavedOrderScreen(
                          status: item['status'],
                          title: item['label'],
                        ),
                  ),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(color: Colors.grey.shade300, blurRadius: 4),
                      ],
                    ),
                    child: Icon(
                      item['icon'],
                      size: 21,
                      color: Color(0xFF0E5C36),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(item['label'], style: TextStyle(fontSize: 10)),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF0F4F5),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Color(0xFFF0F4F5),
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  _buildStatusMenu(),
                  Expanded(
                    child:
                        _savedOrders.isEmpty
                            ? Center(child: Text("No saved orders"))
                            : ListView.builder(
                              itemCount: _savedOrders.length,
                              itemBuilder: (context, index) {
                                final order = _savedOrders[index];
                                return _buildOrderCard(order);
                              },
                            ),
                  ),
                ],
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
        margin: EdgeInsets.only(left: 10, right: 10, top: 4, bottom: 10),
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
