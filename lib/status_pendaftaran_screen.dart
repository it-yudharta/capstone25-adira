import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'bottom_nav_bar_pendaftaran.dart';

class StatusPendaftaranScreen extends StatefulWidget {
  String status;

  StatusPendaftaranScreen({Key? key, required this.status}) : super(key: key);

  @override
  _StatusPendaftaranScreenState createState() =>
      _StatusPendaftaranScreenState();
}

class _StatusPendaftaranScreenState extends State<StatusPendaftaranScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = true;
  List<Map<dynamic, dynamic>> _pendaftarans = [];
  List<Map<dynamic, dynamic>> _filteredPendaftarans = [];
  Map<String, List<Map<dynamic, dynamic>>> groupedPendaftarans = {};
  List<String> orderedDates = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchPendaftarans();
  }

  void _fetchPendaftarans() async {
    final dbRef = FirebaseDatabase.instance.ref().child('agent-form');
    dbRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        final List<Map<dynamic, dynamic>> items = [];
        data.forEach((key, value) {
          final Map<dynamic, dynamic> item = Map<dynamic, dynamic>.from(value);
          item['key'] = key;
          items.add(item);
        });

        setState(() {
          _pendaftarans = items;
          _applySearch();
          _isLoading = false;
        });
      } else {
        setState(() {
          _pendaftarans = [];
          _filteredPendaftarans = [];
          groupedPendaftarans = {};
          orderedDates = [];
          _isLoading = false;
        });
      }
    });
  }

  void _applySearch() {
    _filteredPendaftarans =
        _pendaftarans.where((item) {
          final name = (item['fullName'] ?? '').toString().toLowerCase();
          final status = (item['status'] ?? '').toString().toLowerCase();
          return name.contains(_searchQuery.toLowerCase()) &&
              status == widget.status.toLowerCase();
        }).toList();

    groupedPendaftarans.clear();
    for (var item in _filteredPendaftarans) {
      final date = formatTanggal(item['tanggal']);
      if (!groupedPendaftarans.containsKey(date)) {
        groupedPendaftarans[date] = [];
      }
      groupedPendaftarans[date]!.add(item);
    }

    orderedDates =
        groupedPendaftarans.keys.toList()..sort((a, b) => b.compareTo(a));
  }

  String formatTanggal(dynamic tanggal) {
    if (tanggal is String && tanggal.isNotEmpty) {
      try {
        final parsedDate = DateFormat('d-M-yyyy').parse(tanggal);
        return DateFormat('d-M-yyyy').format(parsedDate);
      } catch (e) {
        return 'Tanggal Invalid';
      }
    }
    return 'Tanggal Kosong';
  }

  void _logout() {
    Navigator.pop(context);
  }

  void _changeStatus(String newStatus) {
    setState(() {
      _isLoading = true;
      widget.status = newStatus;
      _searchQuery = '';
      _searchController.clear();
    });
    _fetchPendaftarans();
  }

  Widget _buildStatusMenu() {
    final List<Map<String, dynamic>> statusButtons = [
      {'label': 'Cancel', 'status': 'cancel', 'icon': Icons.cancel},
      {'label': 'Process', 'status': 'process', 'icon': Icons.hourglass_top},
      {
        'label': 'Pending',
        'status': 'pending',
        'icon': Icons.pause_circle_filled,
      },
      {'label': 'Reject', 'status': 'reject', 'icon': Icons.highlight_off},
      {'label': 'Approve', 'status': 'approve', 'icon': Icons.check_circle},
      {'label': 'QR Given', 'status': 'qr_given', 'icon': Icons.qr_code},
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
                  _changeStatus(item['status']);
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

  Widget _buildPendaftaranCard(
    Map pendaftaran,
    String key,
    TextStyle? baseStyle,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 4)],
      ),
      child: DefaultTextStyle.merge(
        style: baseStyle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Nama       : ${pendaftaran['fullName'] ?? '-'}",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text("Email        : ${pendaftaran['email'] ?? '-'}"),
            Text("Phone      : ${pendaftaran['phone'] ?? '-'}"),
            Text("Alamat      : ${pendaftaran['address'] ?? '-'}"),
            Text("Kode Pos  : ${pendaftaran['postalCode'] ?? '-'}"),
            Text("Status       : ${pendaftaran['status'] ?? 'Belum ada'}"),
          ],
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

        _buildStatusMenu(),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Data Pendaftaran',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ),

        Expanded(
          child:
              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _pendaftarans.isEmpty
                  ? Center(child: Text("Tidak ada data pendaftaran"))
                  : _filteredPendaftarans.isEmpty
                  ? Center(child: Text("Tidak ada hasil pencarian"))
                  : ListView.builder(
                    itemCount: orderedDates.fold<int>(
                      0,
                      (sum, date) =>
                          sum + groupedPendaftarans[date]!.length + 1,
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
                              ),
                            ),
                          );
                        }
                        currentIndex++;

                        final items = groupedPendaftarans[date]!;
                        if (index - currentIndex < items.length) {
                          final item = items[index - currentIndex];
                          return _buildPendaftaranCard(
                            item,
                            item['key'],
                            baseStyle,
                          );
                        }
                        currentIndex += items.length;
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
      bottomNavigationBar: BottomNavBarPendaftaran(currentRoute: 'status'),
    );
  }
}
