import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class StatusSupervisorLead extends StatefulWidget {
  final String status;
  final String type;

  const StatusSupervisorLead({
    super.key,
    required this.status,
    required this.type,
  });

  @override
  _StatusSupervisorLeadState createState() => _StatusSupervisorLeadState();
}

class _StatusSupervisorLeadState extends State<StatusSupervisorLead> {
  final _database = FirebaseDatabase.instance.ref();
  bool _isLoading = false;
  List<Map<dynamic, dynamic>> _filteredData = [];

  @override
  void initState() {
    super.initState();
    _fetchFilteredData();
  }

  void _fetchFilteredData() async {
    setState(() => _isLoading = true);

    if (widget.type == 'pengajuan') {
      final snapshot = await _database.child('orders').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final List<Map<dynamic, dynamic>> result = [];

        data.forEach((key, value) {
          final status = value['status'];
          final isTrash = value['trash'] == true;
          final isLead = value['lead'] == true;

          if (status == widget.status && isLead && !isTrash) {
            value['key'] = key;
            result.add(value);
          }
        });

        setState(() {
          _filteredData = result;
          _isLoading = false;
        });
      }
    } else {
      final snapshot = await _database.child('agent-form').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final List<Map<dynamic, dynamic>> result = [];

        data.forEach((key, value) {
          final status = value['status'];
          final isTrash = value['trash'] == true;
          final isLead = value['lead'] == true;

          if (status == widget.status && isLead && !isTrash) {
            value['key'] = key;
            result.add(value);
          }
        });

        setState(() {
          _filteredData = result;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Lead ${widget.status.capitalize()}"),
        backgroundColor: Color(0xFF0E5C36),
        foregroundColor: Colors.white,
      ),
      backgroundColor: Color(0xFFF0F4F5),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _filteredData.isEmpty
              ? Center(child: Text("Tidak ada data lead ${widget.status}"))
              : ListView.builder(
                  itemCount: _filteredData.length,
                  itemBuilder: (context, index) {
                    final item = _filteredData[index];
                    return Card(
                      margin:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Nama: ${item['name'] ?? item['fullName'] ?? '-'}",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            Text("Email: ${item['email'] ?? '-'}"),
                            Text("Status: ${item['status'] ?? '-'}"),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

extension StringCasingExtension on String {
  String capitalize() =>
      this.length > 0 ? '${this[0].toUpperCase()}${substring(1)}' : '';
}
