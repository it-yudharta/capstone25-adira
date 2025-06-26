import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class StatusAgentLeadScreen extends StatefulWidget {
  final String status;

  const StatusAgentLeadScreen({Key? key, required this.status})
    : super(key: key);

  @override
  _StatusAgentLeadScreenState createState() => _StatusAgentLeadScreenState();
}

class _StatusAgentLeadScreenState extends State<StatusAgentLeadScreen> {
  List<Map<String, dynamic>> filteredOrders = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDataByStatus();
  }

  void _fetchDataByStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final email = user.email;
    final ref = FirebaseDatabase.instance.ref('orders');
    final snapshot = await ref.orderByChild('agentEmail').equalTo(email).get();

    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final List<Map<String, dynamic>> orders = [];

      data.forEach((key, value) {
        final order = Map<String, dynamic>.from(value);
        if (order['lead'] == true && order['status'] == widget.status) {
          order['key'] = key;
          orders.add(order);
        }
      });

      setState(() {
        filteredOrders = orders;
        isLoading = false;
      });
    } else {
      setState(() {
        filteredOrders = [];
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Status: ${widget.status}'),
        backgroundColor: Color(0xFF0E5C36),
        foregroundColor: Colors.white,
      ),
      body:
          isLoading
              ? Center(
                child: CircularProgressIndicator(color: Color(0xFF0E5C36)),
              )
              : filteredOrders.isEmpty
              ? Center(
                child: Text("Tidak ada data dengan status '${widget.status}'"),
              )
              : ListView.builder(
                itemCount: filteredOrders.length,
                itemBuilder: (context, index) {
                  final order = filteredOrders[index];
                  return ListTile(
                    title: Text(order['name'] ?? '-'),
                    subtitle: Text('Status: ${order['status']}'),
                  );
                },
              ),
    );
  }
}
