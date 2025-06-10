import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'order_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'status_supervisor_pengajuan.dart';

class PengajuanSupervisor extends StatefulWidget {
  @override
  _PengajuanSupervisorState createState() => _PengajuanSupervisorState();
}

class _PengajuanSupervisorState extends State<PengajuanSupervisor> {
  final _database = FirebaseDatabase.instance.ref('orders');
  List<Map> _orders = [];
  List<Map> _filteredOrders = [];
  bool _isLoading = false;
  String _searchQuery = '';
  late List<String> orderedDates;
  late Map<String, List<Map>> groupedOrders;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  void _fetchOrders() async {
    setState(() => _isLoading = true);
    final snapshot = await _database.get();

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      final loadedOrders = <Map<dynamic, dynamic>>[];

      data.forEach((key, value) {
        value['key'] = key;
        loadedOrders.add(value);
      });

      setState(() {
        _orders =
            loadedOrders.where((order) {
              final status = order['status'];
              final isTrashed = order['trash'] == true;
              return !isTrashed &&
                  (status == null || status == 'Belum diproses');
            }).toList();

        _applySearch();
        _isLoading = false;
      });
    } else {
      setState(() {
        _orders = [];
        _filteredOrders = [];
        _isLoading = false;
      });
    }
  }

  void _applySearch() {
    _filteredOrders =
        _searchQuery.isEmpty
            ? List.from(_orders)
            : _orders.where((order) {
              final query = _searchQuery.toLowerCase();
              final name = (order['name'] ?? '').toString().toLowerCase();
              final email = (order['email'] ?? '').toString().toLowerCase();
              final agentName =
                  (order['agentName'] ?? '').toString().toLowerCase();
              final tanggal = (order['tanggal'] ?? '').toString().toLowerCase();
              return name.contains(query) ||
                  email.contains(query) ||
                  agentName.contains(query) ||
                  tanggal.contains(query);
            }).toList();
  }

  Map<String, List<Map>> _groupOrdersByDate(List<Map> orders) {
    final Map<String, List<Map>> grouped = {};
    for (var order in orders) {
      final dateStr = order['tanggal'];
      String dateKey;
      try {
        if (dateStr == null || dateStr.isEmpty) throw FormatException();
        DateFormat('d-M-yyyy').parseStrict(dateStr);
        dateKey = dateStr;
      } catch (_) {
        dateKey = 'Tanggal tidak diketahui';
      }
      grouped.putIfAbsent(dateKey, () => []).add(order);
    }

    final sortedKeys =
        grouped.keys.toList()..sort((a, b) {
          try {
            final dateA = DateFormat('d-M-yyyy').parse(a);
            final dateB = DateFormat('d-M-yyyy').parse(b);
            return dateB.compareTo(dateA);
          } catch (_) {
            return a.compareTo(b);
          }
        });

    orderedDates = sortedKeys;
    return grouped;
  }

  String normalizePhoneNumber(String phone) {
    if (phone.startsWith('0')) {
      return '62${phone.substring(1)}';
    }
    return phone;
  }

  Future<void> _launchWhatsApp(String phoneNumber) async {
    final normalizedPhone = normalizePhoneNumber(phoneNumber);
    final url = 'https://wa.me/$normalizedPhone';
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Tidak dapat membuka WhatsApp')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Color(0xFFF0F4F5), body: _buildMainPage());
  }

  Widget _buildOrderCard(Map order, String key, TextStyle? baseStyle) {
    final String phoneNumber = order['phone'] ?? '-';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(orderData: order, orderKey: key),
          ),
        );
      },
      child: Container(
        width: double.infinity,
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
            GestureDetector(
              onTap: () async {
                try {
                  await _launchWhatsApp(phoneNumber);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error launching WhatsApp: $e')),
                  );
                }
              },
              child: Text(
                "No. Telp     : $phoneNumber",
                style: TextStyle(color: Colors.blue),
              ),
            ),
            Text("Pekerjaan  : ${order['job'] ?? '-'}"),
            Text("Pengajuan : ${order['installment'] ?? '-'}"),
            SizedBox(height: 8),
            Text("Status        : ${order['status'] ?? 'Belum diproses'}"),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusMenu() {
    final List<Map<String, dynamic>> statusButtons = [
      {'label': 'Cancel', 'status': 'cancel', 'icon': Icons.cancel},
      {'label': 'Process', 'status': 'process', 'icon': Icons.hourglass_bottom},
      {
        'label': 'Pending',
        'status': 'pending',
        'icon': Icons.pause_circle_filled,
      },
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
                        (_) => StatusSupervisorPengajuan(
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

  Widget _buildMainPage() {
    final baseStyle = Theme.of(context).textTheme.bodyMedium;
    groupedOrders = _groupOrdersByDate(_filteredOrders);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Container(
            width: 250,
            height: 40,
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _applySearch();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search data',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.black, width: 1.2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: Colors.grey.shade500,
                    width: 1.2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Color(0xFF0E5C36), width: 1.5),
                ),
                filled: true,
                fillColor: Colors.white,
                suffixIcon: Icon(Icons.search, color: Colors.grey.shade600),
              ),
              style: TextStyle(fontSize: 14),
            ),
          ),
        ),
        SizedBox(height: 12),
        Expanded(
          child:
              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _filteredOrders.isEmpty
                  ? Center(child: Text("Tidak ada data ditemukan"))
                  : ListView.builder(
                    itemCount: orderedDates.fold<int>(
                      0,
                      (sum, date) => sum + groupedOrders[date]!.length + 1,
                    ),
                    itemBuilder: (context, index) {
                      int currentIndex = 0;
                      for (final date in orderedDates) {
                        if (index == currentIndex) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              'Date: $date',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          );
                        }
                        currentIndex++;

                        final orders = groupedOrders[date]!;
                        if (index - currentIndex < orders.length) {
                          final order = orders[index - currentIndex];
                          return _buildOrderCard(
                            order,
                            order['key'],
                            baseStyle,
                          );
                        }
                        currentIndex += orders.length;
                      }
                      return SizedBox.shrink();
                    },
                  ),
        ),
      ],
    );
  }
}
