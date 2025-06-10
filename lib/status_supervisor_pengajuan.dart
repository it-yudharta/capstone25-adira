import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'navbar_supervisor.dart';

class StatusSupervisorPengajuan extends StatefulWidget {
  final String status;
  final String title;

  const StatusSupervisorPengajuan({
    Key? key,
    required this.status,
    required this.title,
  }) : super(key: key);

  @override
  _StatusSupervisorPengajuanState createState() =>
      _StatusSupervisorPengajuanState();
}

class _StatusSupervisorPengajuanState extends State<StatusSupervisorPengajuan> {
  List<Map<dynamic, dynamic>> _orders = [];
  List<Map<dynamic, dynamic>> _filteredOrders = [];
  Map<String, List<Map<dynamic, dynamic>>> groupedOrders = {};
  List<String> orderedDates = [];
  String _searchQuery = '';
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

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

  void _logout() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F5),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFF0F4F5),
        elevation: 0,
        foregroundColor: Colors.black,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Color(0xFFF0F4F5),
          statusBarIconBrightness: Brightness.dark,
        ),
        title: Row(
          children: [
            RichText(
              text: TextSpan(
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
            Spacer(),
            IconButton(
              icon: Icon(Icons.logout, color: Colors.black),
              onPressed: _logout,
            ),
          ],
        ),
      ),
      body: _buildMainPage(),
      bottomNavigationBar: BottomNavBarSupervisor(currentRoute: 'status'),
    );
  }

  Widget _buildMainPage() {
    final baseStyle = Theme.of(context).textTheme.bodyMedium;

    return Column(
      children: [
        // Search bar
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
                hintText: 'Search Data',
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
                  borderSide: BorderSide(color: Color(0xFF0E5C36), width: 1.5),
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
                  onPressed: () {
                    FocusScope.of(context).requestFocus(_focusNode);
                  },
                ),
              ),
              style: TextStyle(fontSize: 14),
            ),
          ),
        ),

        // Tombol atas (hanya export)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Data Pengajuan',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF0E5C36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                      'Export by',
                      style: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child:
              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _filteredOrders.isEmpty
                  ? Center(child: Text("Tidak ada hasil pencarian"))
                  : ListView.builder(
                    itemCount: orderedDates.length,
                    itemBuilder: (context, index) {
                      final date = orderedDates[index];
                      final orders = groupedOrders[date] ?? [];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              'Date: $date',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ...orders
                              .map((order) => _buildOrderCard(order))
                              .toList(),
                        ],
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(Map order) {
    final phone = order['phone'] ?? '-';
    final status = order['status'] ?? 'Belum diproses';
    final isLead = order['lead'] == true;
    final key = order['key'];

    return InkWell(
      onTap: () {
        // Navigasi ke detail jika diperlukan
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: EdgeInsets.all(12),
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
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text("Email         : ${order['email'] ?? '-'}"),
                SizedBox(height: 4),
                GestureDetector(
                  onTap: () async {
                    // Implementasi buka WhatsApp
                  },
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                      children: [
                        TextSpan(text: "No. Telp     : "),
                        TextSpan(
                          text: phone,
                          style: TextStyle(color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 4),
                Text("Alamat      : ${order['address'] ?? '-'}"),
                SizedBox(height: 4),
                Text("Kode Pos  : ${order['postalCode'] ?? '-'}"),
                SizedBox(height: 4),
                Text("Status       : $status"),
                SizedBox(height: 16),
                if ((status.toLowerCase() == 'process') &&
                    widget.status != 'trash')
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () {
                        // Aksi Cancel di Supervisor
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
                          Icon(Icons.cancel, size: 16, color: Colors.white),
                          SizedBox(height: 4),
                          Text(
                            'Cancel',
                            style: TextStyle(fontSize: 12, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            if (isLead)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.only(top: 8, right: 36),
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

            Positioned(
              top: 0,
              right: 0,
              child: PopupMenuButton<String>(
                onSelected: (value) async {
                  // Menu tindakan seperti 'lead', 'delete'
                },
                itemBuilder: (BuildContext context) {
                  return [
                    if (!isLead)
                      PopupMenuItem<String>(value: 'lead', child: Text('Lead')),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ];
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
