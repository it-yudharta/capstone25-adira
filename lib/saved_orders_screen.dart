import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'order_detail_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF0F4F5),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Color(0xFFF0F4F5),
        elevation: 0,
        foregroundColor: Colors.black,
        title: Row(
          children: [
            Text(
              'Lead Orders',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Spacer(),
            IconButton(
              icon: Icon(Icons.arrow_back, color: Color(0xFFE67D13)),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _savedOrders.isEmpty
              ? Center(child: Text("No saved orders"))
              : ListView.builder(
                itemCount: _savedOrders.length,
                itemBuilder: (context, index) {
                  final order = _savedOrders[index];
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
            Text("Status        : ${order['status'] ?? 'Belum diproses'}"),
            Positioned(
              top: 4,
              left: 260,
              child: Transform.scale(
                scaleY: 1.3,
                scaleX: 1.0,
                child: Icon(Icons.bookmark, size: 24, color: Colors.orange),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
