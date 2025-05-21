import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'custom_bottom_nav_bar.dart';
import 'order_detail_screen.dart';

class StatusPengajuanScreen extends StatefulWidget {
  String status;
  String title;

  StatusPengajuanScreen({Key? key, required this.status, required this.title})
    : super(key: key);

  @override
  _StatusPengajuanScreenState createState() => _StatusPengajuanScreenState();
}

class _StatusPengajuanScreenState extends State<StatusPengajuanScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = true;
  List<Map<dynamic, dynamic>> _orders = [];
  List<Map<dynamic, dynamic>> _filteredOrders = [];
  Map<String, List<Map<dynamic, dynamic>>> groupedOrders = {};
  List<String> orderedDates = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  void _fetchOrders() async {
    final dbRef = FirebaseDatabase.instance.ref().child('orders');

    if (widget.status == 'trash') {
      dbRef.onValue.listen((event) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;

        if (data != null) {
          final List<Map<dynamic, dynamic>> items = [];
          data.forEach((key, value) {
            final Map<dynamic, dynamic> item = Map<dynamic, dynamic>.from(
              value,
            );
            if (item['trash'] == true) {
              item['key'] = key;
              items.add(item);
            }
          });

          setState(() {
            _orders = items;
            _applySearch();
            _isLoading = false;
          });
        } else {
          setState(() {
            _orders = [];
            _filteredOrders = [];
            groupedOrders = {};
            orderedDates = [];
            _isLoading = false;
          });
        }
      });
    } else {
      dbRef.orderByChild('status').equalTo(widget.status).onValue.listen((
        event,
      ) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;

        if (data != null) {
          final List<Map<dynamic, dynamic>> items = [];
          data.forEach((key, value) {
            final Map<dynamic, dynamic> item = Map<dynamic, dynamic>.from(
              value,
            );
            if (item['trash'] != true) {
              item['key'] = key;
              items.add(item);
            }
          });

          setState(() {
            _orders = items;
            _applySearch();
            _isLoading = false;
          });
        } else {
          setState(() {
            _orders = [];
            _filteredOrders = [];
            groupedOrders = {};
            orderedDates = [];
            _isLoading = false;
          });
        }
      });
    }
  }

  void _applySearch() {
    _filteredOrders =
        _orders.where((order) {
          final name = (order['name'] ?? '').toString().toLowerCase();
          return name.contains(_searchQuery.toLowerCase());
        }).toList();

    groupedOrders.clear();
    for (var order in _filteredOrders) {
      final date = order['tanggal'] ?? '';
      if (!groupedOrders.containsKey(date)) {
        groupedOrders[date] = [];
      }
      groupedOrders[date]!.add(order);
    }

    orderedDates =
        groupedOrders.keys.toList()..sort((a, b) {
          DateTime parseDate(String d) {
            final parts = d.split('-');
            return DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
          }

          return parseDate(b).compareTo(parseDate(a));
        });
  }

  void updateStatus(String key, String newStatus) async {
    final now = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final dbRef = FirebaseDatabase.instance.ref().child('orders/$key');
    await dbRef.update({'status': newStatus, 'statusUpdatedAt': now});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Status berhasil diubah menjadi $newStatus')),
    );
  }

  void _changeStatus(String newStatus, String newTitle) {
    setState(() {
      _isLoading = true;
      _orders = [];
      _filteredOrders = [];
      groupedOrders = {};
      orderedDates = [];
      widget.status = newStatus;
      widget.title = newTitle;
    });
    _fetchOrders();
  }

  void _logout() {
    Navigator.pop(context);
  }

  Future<void> _launchWhatsApp(String phoneNumber) async {
    final Uri url = Uri.parse("https://wa.me/$phoneNumber");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  Future<void> _updateLeadStatus(String orderKey, bool isLead) async {
    final dbRef = FirebaseDatabase.instance.ref().child('orders/$orderKey');
    await dbRef.update({'lead': isLead});
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
            final bool isActive = widget.status == item['status'];

            return InkWell(
              onTap: () {
                if (!isActive) {
                  _changeStatus(item['status'], item['label']);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isActive ? Color(0xFF0E5C36) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(color: Colors.grey.shade300, blurRadius: 4),
                      ],
                    ),
                    child: Icon(
                      item['icon'],
                      size: 21,
                      color: isActive ? Colors.white : Color(0xFF0E5C36),
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

  Widget _buildOrderCard(Map order, String orderKey, TextStyle? baseStyle) {
    final isLead = order['lead'] == true;
    final String phoneNumber = order['phone'] ?? '-';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) =>
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
                  if (widget.status == 'process')
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            onPressed:
                                () => updateStatus(order['key'], 'cancel'),
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
                                  Icons.cancel,
                                  size: 16,
                                  color: Colors.white,
                                ),
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
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) {
                                  TextEditingController _noteController =
                                      TextEditingController();
                                  return AlertDialog(
                                    title: Text('Add Note'),
                                    content: TextField(
                                      controller: _noteController,
                                      decoration: InputDecoration(
                                        hintText: 'Tulis catatan...',
                                      ),
                                      maxLines: 3,
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text('Batal'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () async {
                                          final note =
                                              _noteController.text.trim();
                                          if (note.isNotEmpty) {
                                            final dbRef = FirebaseDatabase
                                                .instance
                                                .ref()
                                                .child(
                                                  'orders/${order['key']}',
                                                );
                                            await dbRef.update({'note': note});
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Catatan berhasil ditambahkan',
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        child: Text('Simpan'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
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
                                  Icons.note_add,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Add Note',
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
            if (isLead)
              Positioned(
                top: 4,
                left: 260,
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
            Positioned(
              top: 0,
              right: 0,
              child: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'lead') {
                    setState(() => order['lead'] = true);
                    _updateLeadStatus(orderKey, true);
                  } else if (value == 'unlead') {
                    setState(() => order['lead'] = false);
                    _updateLeadStatus(orderKey, false);
                  }
                },
                itemBuilder:
                    (BuildContext context) => [
                      if (!isLead)
                        PopupMenuItem<String>(
                          value: 'lead',
                          child: Text('Tandai sebagai Lead'),
                        ),
                      if (isLead)
                        PopupMenuItem<String>(
                          value: 'unlead',
                          child: Text('Batalkan Lead'),
                        ),
                    ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _customMenuItem(
    IconData icon,
    String label,
    String value,
  ) {
    return PopupMenuItem<String>(
      value: value,
      padding: EdgeInsets.zero,
      height: 36,
      child: Container(
        color: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Color(0xFF0E5C36)),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 14, color: Color(0xFF0E5C36)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodyMedium;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F5),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFF0F4F5),
        elevation: 0,
        foregroundColor: Colors.black,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFFF0F4F5),
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        title: Row(
          children: [
            RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(
                    text: 'Fundra',
                    style: TextStyle(color: Color(0xFF0E5C36)),
                  ),
                  TextSpan(
                    text: 'IN',
                    style: TextStyle(color: Color(0xFFE67D13)),
                  ),
                ],
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.black),
              onPressed: _logout,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: SizedBox(
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
                  contentPadding: const EdgeInsets.symmetric(
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
                    borderSide: const BorderSide(
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
          const SizedBox(height: 8),
          _buildStatusMenu(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    backgroundColor: const Color(0xFF0E5C36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Export All',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _orders.isEmpty
                    ? const Center(child: Text("Tidak ada pengajuan baru"))
                    : _filteredOrders.isEmpty
                    ? const Center(child: Text("Tidak ada hasil pencarian"))
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
                                style: const TextStyle(
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
                        return const SizedBox.shrink();
                      },
                    ),
          ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNavBar(currentRoute: 'other'),
    );
  }
}
