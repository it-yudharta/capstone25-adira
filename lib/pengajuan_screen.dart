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

  final List<String> _statusList = [
    'disetujui',
    'ditolak',
    'dibatalkan',
    'diproses',
    'dipending',
  ];

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
    _focusNode.addListener(() {
      setState(() {});
    });
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
    return DateFormat('d-M-yyyy').format(dateTime);
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
      {'label': 'Batal', 'status': 'dibatalkan', 'icon': Icons.cancel},
      {'label': 'Proses', 'status': 'diproses', 'icon': Icons.hourglass_bottom},
      {'label': 'Pending', 'status': 'dipending', 'icon': Icons.pause_circle},
      {'label': 'Tolak', 'status': 'ditolak', 'icon': Icons.block},
      {'label': 'Setuju', 'status': 'disetujui', 'icon': Icons.check_circle},
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

  bool isPressed = false;

  Map<String, List<Map>> _groupOrdersByDate(List<Map> orders) {
    final Map<String, List<Map>> grouped = {};
    for (var order in orders) {
      final date = order['timestamp'] ?? 'Tanggal tidak diketahui';
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(order);
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
                  onPressed: () {
                    FocusScope.of(context).requestFocus(_focusNode);
                    _applySearch();
                  },
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
                          final orderKey = order['key'];
                          return _buildOrderCard(order, orderKey, baseStyle);
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

      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: Colors.white,
          shadowColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          elevation: 0,
          currentIndex: _currentPage,
          onTap: (index) {
            _pageController.animateToPage(
              index,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
          selectedItemColor: Color(0xFFE67D13),
          unselectedItemColor: Colors.black,
          selectedLabelStyle: TextStyle(fontSize: 12),
          unselectedLabelStyle: TextStyle(fontSize: 12),
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.insert_drive_file),
              label: 'Pengajuan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.qr_code),
              label: 'QR Code',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment),
              label: 'Pendaftaran Agent',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: 'Lead'),
          ],
        ),
      ),
    );
  }
}
