import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'status_pengajuan_screen.dart';
import 'trash_screen.dart';
import 'saved_orders_screen.dart';
import 'generate_qr_screen.dart';
import 'pendaftaran_screen.dart';
import 'login_screen.dart';
import 'order_detail_screen.dart';
import 'package:flutter/services.dart';

class PengajuanScreen extends StatefulWidget {
  @override
  _PengajuanScreenState createState() => _PengajuanScreenState();
}

class _PengajuanScreenState extends State<PengajuanScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final DatabaseReference _database = FirebaseDatabase.instance.ref().child(
    'orders',
  );
  final TextEditingController _searchController = TextEditingController();

  List<Map<dynamic, dynamic>> _orders = [];
  List<Map<dynamic, dynamic>> _filteredOrders = [];
  String _searchQuery = '';
  bool _isLoading = false;
  final FocusNode _focusNode = FocusNode();

  List<String> get orderedDates {
    final grouped = groupedOrders;
    final dates = grouped.keys.toList();
    dates.sort((a, b) {
      final dateA = DateFormat('d-M-yyyy').parse(a);
      final dateB = DateFormat('d-M-yyyy').parse(b);
      return dateB.compareTo(dateA);
    });
    return dates;
  }

  Map<String, List<Map>> get groupedOrders {
    return _groupOrdersByDate(_filteredOrders);
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
    _fetchOrders();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _fetchOrders() async {
    setState(() => _isLoading = true);
    final snapshot = await _database.get();
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      final loadedOrders = <Map<dynamic, dynamic>>[];

      data.forEach((key, value) {
        if (value['timestamp'] != null && value['timestamp'] is int) {
          value['timestamp'] = _convertTimestamp(value['timestamp']);
        }
        value['key'] = key;
        loadedOrders.add(value);
      });

      setState(() {
        _orders = loadedOrders;
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
              return name.contains(query) ||
                  email.contains(query) ||
                  agentName.contains(query);
            }).toList();
  }

  String _convertTimestamp(int timestamp) {
    return DateFormat(
      'd-M-yyyy',
    ).format(DateTime.fromMillisecondsSinceEpoch(timestamp));
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => LoginScreen()));
  }

  void _updateLeadStatus(String orderKey, bool isLead) async {
    final orderRef = _database.child(orderKey);
    try {
      await orderRef.update({'lead': isLead});
    } catch (error) {
      print("Failed to update lead status: $error");
    }
  }

  Widget _buildOrderCard(Map order, String orderKey, TextStyle? baseStyle) {
    final isLead = order['lead'] == true;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => OrderDetailScreen(orderData: order, orderKey: orderKey),
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
              padding: const EdgeInsets.only(right: 32),
              child: DefaultTextStyle.merge(
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
                    Text("No. Telp     : ${order['phone'] ?? '-'}"),
                    Text("Pekerjaan  : ${order['job'] ?? '-'}"),
                    Text("Pengajuan : ${order['installment'] ?? '-'}"),
                    SizedBox(height: 8),
                    Text(
                      "Status        : ${order['status'] ?? 'Belum diproses'}",
                    ),
                  ],
                ),
              ),
            ),
            if (isLead)
              Positioned(
                top: 4,
                left: 260,
                child: Transform.scale(
                  scaleY: 1.3,
                  scaleX: 1.0,
                  child: Icon(Icons.bookmark, size: 24, color: Colors.orange),
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

  Widget _buildStatusMenu() {
    final List<Map<String, dynamic>> statusButtons = [
      {'label': 'Batal', 'status': 'batal', 'icon': Icons.cancel},
      {'label': 'Proses', 'status': 'proses', 'icon': Icons.hourglass_bottom},
      {'label': 'Pending', 'status': 'pending', 'icon': Icons.pause_circle},
      {'label': 'Tolak', 'status': 'tolak', 'icon': Icons.block},
      {'label': 'Setuju', 'status': 'setuju', 'icon': Icons.check_circle},
      {'label': 'Lead', 'status': 'lead', 'icon': Icons.bookmark},
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
                if (item['status'] == 'lead') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SavedOrdersScreen()),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => StatusPengajuanScreen(
                            status: item['status'],
                            title: item['label'],
                          ),
                    ),
                  );
                }
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
                      color: Color(0xFFE67D13),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(item['label'], style: TextStyle(fontSize: 12)),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Map<String, List<Map>> _groupOrdersByDate(List<Map> orders) {
    final Map<String, List<Map>> grouped = {};
    for (var order in orders) {
      final date = order['timestamp'] ?? 'Tanggal tidak diketahui';
      grouped.putIfAbsent(date, () => []).add(order);
    }
    return grouped;
  }

  Widget _buildMainPage() {
    final baseStyle = Theme.of(context).textTheme.bodyMedium;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
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
                  borderSide: BorderSide(color: Color(0xFFE67D13), width: 1.5),
                ),
                filled: true,
                fillColor: Colors.white,
                suffixIcon: IconButton(
                  icon: Icon(
                    Icons.search,
                    color:
                        _focusNode.hasFocus
                            ? Color(0xFFE67D13)
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
        SizedBox(height: 8),
        _buildStatusMenu(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  backgroundColor: Color(0xFFE67D13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Export All', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        Expanded(
          child:
              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _orders.isEmpty
                  ? Center(child: Text("Tidak ada pengajuan baru"))
                  : _filteredOrders.isEmpty
                  ? Center(child: Text("Tidak ada hasil pencarian"))
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF0F4F5),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Color(0xFFF0F4F5),
        elevation: 0,
        foregroundColor: Colors.black,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Color(0xFFF0F4F5),
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        title: Row(
          children: [
            RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(
                    text: 'Fundra',
                    style: TextStyle(color: Color(0xFFEA7D10)),
                  ),
                  TextSpan(
                    text: 'IN',
                    style: TextStyle(color: Color(0xFF0C2BC5)),
                  ),
                ],
              ),
            ),
            Spacer(),
            IconButton(
              icon: Icon(Icons.logout, color: Color(0xFFE67D13)),
              onPressed: _logout,
            ),
          ],
        ),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentPage = index),
        children: [
          _buildMainPage(),
          GenerateQRScreen(),
          PendaftaranScreen(),
          SavedOrdersScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        elevation: 0,
        currentIndex: _currentPage,
        onTap:
            (index) => _pageController.animateToPage(
              index,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
        selectedItemColor: Color(0xFFE67D13),
        unselectedItemColor: Colors.black,
        selectedLabelStyle: TextStyle(fontSize: 12),
        unselectedLabelStyle: TextStyle(fontSize: 12),
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.insert_drive_file),
            label: 'Pengajuan',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code), label: 'QR Code'),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Pendaftaran Agent',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: 'Lead'),
        ],
      ),
    );
  }
}
