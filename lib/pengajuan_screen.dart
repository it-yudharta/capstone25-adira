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

  final List<String> _statusList = [
    'disetujui',
    'ditolak',
    'dibatalkan',
    'diproses',
    'dipending',
  ];

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
        final status = value['status']?.toString().toLowerCase() ?? '';
        if (status.isEmpty || status == 'belum diproses') {
          if (value['timestamp'] != null && value['timestamp'] is int) {
            value['timestamp'] = _convertTimestamp(value['timestamp']);
          }
          value['key'] = key;
          loadedOrders.add(value);
        }
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
    if (_searchQuery.isEmpty) {
      _filteredOrders = List.from(_orders);
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredOrders =
          _orders.where((order) {
            final name = (order['name'] ?? '').toString().toLowerCase();
            final email = (order['email'] ?? '').toString().toLowerCase();
            final agentName =
                (order['agentName'] ?? '').toString().toLowerCase();
            return name.contains(query) ||
                email.contains(query) ||
                agentName.contains(query);
          }).toList();
    }
  }

  String _convertTimestamp(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('dd MMM yyyy').format(dateTime);
  }

  void _updateStatus(String key, String newStatus) async {
    await _database.child(key).update({'status': newStatus});
    _fetchOrders();
  }

  void _showStatusSelector(String key) {
    showModalBottomSheet(
      context: context,
      builder:
          (_) => Column(
            mainAxisSize: MainAxisSize.min,
            children:
                _statusList.map((status) {
                  return ListTile(
                    title: Text(
                      'Setel ke: ${status[0].toUpperCase()}${status.substring(1)}',
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _updateStatus(key, status);
                    },
                  );
                }).toList(),
          ),
    );
  }

  void _navigateToStatusScreen(String status) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StatusPengajuanScreen(status: status)),
    );
  }

  void _navigateToTrashScreen() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => TrashScreen()));
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _applySearch();
    });
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => LoginScreen()));
  }

  Widget _buildOrderCard(Map order, String orderKey, TextStyle? baseStyle) {
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
        margin: EdgeInsets.all(10),
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
              Text("Status        : ${order['status'] ?? 'Belum diproses'}"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusMenu() {
    final List<Map<String, dynamic>> statusButtons = [
      {'label': 'batal', 'status': 'dibatalkan', 'icon': Icons.cancel},
      {'label': 'proses', 'status': 'diproses', 'icon': Icons.hourglass_bottom},
      {'label': 'pending', 'status': 'dipending', 'icon': Icons.pause_circle},
      {'label': 'tolak', 'status': 'ditolak', 'icon': Icons.block},
      {'label': 'setuju', 'status': 'disetujui', 'icon': Icons.check_circle},
      {'label': 'trash', 'status': 'trash', 'icon': Icons.delete},
    ];

    return Container(
      margin: EdgeInsets.symmetric(vertical: 10, horizontal: 11),
      padding: EdgeInsets.symmetric(horizontal: 29, vertical: 8),
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
                if (item['status'] == 'trash') {
                  _navigateToTrashScreen();
                } else {
                  _navigateToStatusScreen(item['status']);
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

  Widget _buildMainPage() {
    final baseStyle = Theme.of(context).textTheme.bodyMedium;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Container(
            width: 250,
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _applySearch();
                });
              },
              decoration: InputDecoration(
                hintText: 'Cari Data',
                contentPadding: EdgeInsets.symmetric(horizontal: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.black),
                ),
                fillColor: Colors.white,
                filled: true,
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () {},
                ),
              ),
              style: TextStyle(fontSize: 14),
            ),
          ),
        ),
        SizedBox(height: 8),
        _buildStatusMenu(),
        Expanded(
          child:
              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _orders.isEmpty
                  ? Center(child: Text("Tidak ada pengajuan baru"))
                  : _filteredOrders.isEmpty
                  ? Center(child: Text("Tidak ada hasil pencarian"))
                  : ListView.builder(
                    itemCount: _filteredOrders.length,
                    itemBuilder: (context, index) {
                      final order = _filteredOrders[index];
                      final orderKey = order['key'];
                      return _buildOrderCard(order, orderKey, baseStyle);
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildOutlinedIcon(IconData iconData, bool isSelected) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          String.fromCharCode(iconData.codePoint),
          style: TextStyle(
            inherit: false,
            fontSize: 24,
            fontFamily: iconData.fontFamily,
            package: iconData.fontPackage,
            foreground:
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.8
                  ..color = Colors.black,
          ),
        ),
        Icon(
          iconData,
          size: 24,
          color: isSelected ? Colors.blue : Colors.white,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 2,
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
          SavedOrdersScreen(), // Lead
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentPage,
        onTap: (index) {
          _pageController.animateToPage(
            index,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        backgroundColor: Colors.white,
        selectedItemColor: Color(0xFFE67D13),
        unselectedItemColor: Colors.black,
        selectedLabelStyle: TextStyle(fontSize: 12, color: Color(0xFFE67D13)),
        unselectedLabelStyle: TextStyle(fontSize: 12, color: Colors.black),
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
