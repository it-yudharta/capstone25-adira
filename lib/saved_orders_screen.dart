import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'order_detail_screen.dart';
import 'status_saved_order_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class SavedOrdersScreen extends StatefulWidget {
  @override
  _SavedOrdersScreenState createState() => _SavedOrdersScreenState();
}

class _SavedOrdersScreenState extends State<SavedOrdersScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref().child(
    'orders',
  );
  List<Map<dynamic, dynamic>> _savedOrders = [];
  List<Map<dynamic, dynamic>> _filteredOrders = [];
  String _searchQuery = '';
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _fetchSavedOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _fetchSavedOrders() async {
    setState(() => _isLoading = true);
    final snapshot = await _database.get();
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      final loadedOrders = <Map<dynamic, dynamic>>[];

      data.forEach((key, value) {
        final status = value['status'];
        if (value['lead'] == true &&
            (status == null || status == 'belum diproses')) {
          value['key'] = key;
          loadedOrders.add(value);
        }
      });

      setState(() {
        _savedOrders = loadedOrders;
        _filteredOrders = List.from(_savedOrders);
        groupedOrders = _groupOrdersByDate(_filteredOrders);
        _isLoading = false;
      });
    } else {
      setState(() {
        _savedOrders = [];
        _filteredOrders = [];
        _isLoading = false;
      });
    }
  }

  String normalizePhoneNumber(String phone) {
    if (phone.startsWith('0')) {
      return '62${phone.substring(1)}';
    }
    return phone;
  }

  List<String> get orderedDates {
    final grouped = groupedOrders;
    final dates = grouped.keys.toList();

    dates.sort((a, b) {
      DateTime? dateA, dateB;

      try {
        dateA = DateFormat('d-M-yyyy').parseStrict(a);
      } catch (_) {
        dateA = null;
      }
      try {
        dateB = DateFormat('d-M-yyyy').parseStrict(b);
      } catch (_) {
        dateB = null;
      }

      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });

    return dates;
  }

  Map<String, List<Map<dynamic, dynamic>>> groupedOrders = {};

  Map<String, List<Map<dynamic, dynamic>>> _groupOrdersByDate(
    List<Map<dynamic, dynamic>> orders,
  ) {
    final Map<String, List<Map<dynamic, dynamic>>> grouped = {};
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
    return grouped;
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredOrders = List.from(_savedOrders);
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredOrders =
          _savedOrders.where((order) {
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
    groupedOrders = _groupOrdersByDate(_filteredOrders);
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
      margin: EdgeInsets.symmetric(vertical: 10, horizontal: 0),
      padding: EdgeInsets.symmetric(horizontal: 19, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 5)],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children:
            statusButtons.map((item) {
              return Expanded(
                child: InkWell(
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
                            BoxShadow(
                              color: Colors.grey.shade300,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          item['icon'],
                          size: 21,
                          color: Color(0xFF0E5C36),
                        ),
                      ),
                      SizedBox(height: 4),
                      FittedBox(
                        child: Text(
                          item['label'],
                          style: TextStyle(fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildMainPage() {
    return _isLoading
        ? Center(child: CircularProgressIndicator())
        : Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Container(
                width: 250,
                height: 40,
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
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
                      borderSide: BorderSide(
                        color: Color(0xFF0E5C36),
                        width: 1.5,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: IconButton(
                      icon: Icon(
                        Icons.search,
                        color:
                            _focusNode.hasFocus
                                ? Color(0xFF0E5C36)
                                : Colors.grey.shade600,
                      ),
                      onPressed:
                          () => FocusScope.of(context).requestFocus(_focusNode),
                    ),
                  ),
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: _buildStatusMenu(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF0E5C36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: Colors.white,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Delete All',
                          style: TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF0E5C36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/icon/export_icon.png',
                          width: 16,
                          height: 16,
                          color: Colors.white,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Export All',
                          style: TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Expanded(
              child:
                  _savedOrders.isEmpty
                      ? Center(child: Text("No saved orders"))
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
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  4,
                                ),
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
                              return _buildOrderCard(order, null);
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

  void _updateOrderStatus(String orderKey, String newStatus) async {
    final now = DateTime.now();
    final formattedDate = DateFormat('dd-MM-yyyy').format(now);

    Map<String, dynamic> updates = {
      'status': newStatus,
      '${newStatus}UpdatedAt': formattedDate,
    };

    try {
      await _database.child(orderKey).update(updates);
      _fetchSavedOrders();
    } catch (e) {
      print("Gagal memperbarui status: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memperbarui status')));
    }
  }

  Widget _buildOrderCard(Map order, TextStyle? baseStyle) {
    final isLead = order['lead'] == true;
    final String phoneNumber = order['phone'] ?? '-';

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
            DefaultTextStyle.merge(
              style: baseStyle,
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
                          SnackBar(
                            content: Text('Error launching WhatsApp: $e'),
                          ),
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
                  if (!(isLead && (order['status'] == 'lead')))
                    Text(
                      "Status        : ${order['status'] ?? 'Belum diproses'}",
                    ),
                  SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed:
                              () => _updateOrderStatus(order['key'], 'cancel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF0E5C36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.cancel, size: 16, color: Colors.white),
                              SizedBox(height: 4),
                              Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 6),
                        ElevatedButton(
                          onPressed:
                              () => _updateOrderStatus(order['key'], 'process'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF0E5C36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.hourglass_bottom,
                                size: 16,
                                color: Colors.white,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Process',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F5),
      body: _buildMainPage(),
    );
  }
}
