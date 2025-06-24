import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'order_detail_screen.dart';

class StatusAgentScreen extends StatefulWidget {
  final String status;
  const StatusAgentScreen({Key? key, required this.status}) : super(key: key);

  @override
  _StatusAgentScreenState createState() => _StatusAgentScreenState();
}

class _StatusAgentScreenState extends State<StatusAgentScreen> {
  List<Map<String, dynamic>> filteredOrders = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStatusOrders();
  }

  void _fetchStatusOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final email = user.email;

    final ref = FirebaseDatabase.instance.ref('orders');
    final snapshot = await ref.orderByChild('agentEmail').equalTo(email).get();

    if (snapshot.exists) {
      final Map data = snapshot.value as Map;
      final orders =
          data.entries.map<Map<String, dynamic>>((entry) {
            final value = Map<String, dynamic>.from(entry.value);
            value['key'] = entry.key;
            return value;
          }).toList();

      final filtered =
          orders.where((order) => order['status'] == widget.status).toList();

      setState(() {
        filteredOrders = filtered;
        isLoading = false;
      });
    } else {
      setState(() {
        filteredOrders = [];
        isLoading = false;
      });
    }
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final phone = order['phone'] ?? '-';
    final status = order['status'] ?? 'Belum diproses';
    final isLead = order['lead'] == true;
    final key = order['key'];

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => OrderDetailScreen(orderData: order, orderKey: key),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 4)],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Nama        : ${order['name'] ?? '-'}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text("Email         : ${order['email'] ?? '-'}"),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    children: [
                      const TextSpan(text: "No. Telp     : "),
                      TextSpan(
                        text: phone,
                        style: const TextStyle(color: Colors.blue),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text("Alamat      : ${order['domicile'] ?? '-'}"),
                const SizedBox(height: 4),
                Text("Kode Pos  : ${order['postalCode'] ?? '-'}"),
                const SizedBox(height: 4),
                Text(
                  "Status        : $status",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (order['note'] != null &&
                    order['note'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      "Note           : ${order['note']}",
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            if (isLead)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.only(top: 8, right: 8),
                  child: Transform.scale(
                    scaleY: 1.3,
                    scaleX: 1.0,
                    child: Icon(
                      Icons.bookmark,
                      size: 24,
                      color: Color(0xFF0E5C36),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Status: ${widget.status}')),
      body:
          isLoading
              ? Center(child: CircularProgressIndicator())
              : filteredOrders.isEmpty
              ? Center(child: Text("Tidak ada data status '${widget.status}'"))
              : ListView.builder(
                itemCount: filteredOrders.length,
                itemBuilder: (context, index) {
                  final order = filteredOrders[index];
                  return _buildOrderCard(order);
                },
              ),
    );
  }
}
