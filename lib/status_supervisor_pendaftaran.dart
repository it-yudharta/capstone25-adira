import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'navbar_supervisor.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class StatusSupervisorPendaftaran extends StatefulWidget {
  final String status;

  const StatusSupervisorPendaftaran({Key? key, required this.status})
    : super(key: key);

  @override
  _StatusSupervisorPendaftaranState createState() =>
      _StatusSupervisorPendaftaranState();
}

class _StatusSupervisorPendaftaranState
    extends State<StatusSupervisorPendaftaran> {
  List<Map> _pendaftarans = [];
  List<Map> _filteredPendaftarans = [];
  Map<String, List<Map>> groupedPendaftarans = {};
  List<String> orderedDates = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = '';
  late String _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.status;
    _fetchPendaftarans();
  }

  Future<void> _fetchPendaftarans() async {
    final dbRef = FirebaseDatabase.instance.ref().child('agent-form');

    dbRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        final items = <Map>[];
        data.forEach((key, value) {
          final item = Map<dynamic, dynamic>.from(value);
          final status = (item['status'] ?? '').toString().toLowerCase();
          final trash = item['trash'] == true || item['trash'] == 'true';

          if (trash && widget.status == 'trash') {
            item['key'] = key;
            items.add(item);
          } else if (!trash && status == _currentStatus.toLowerCase()) {
            item['key'] = key;
            items.add(item);
          }
        });

        setState(() {
          _pendaftarans = items;
          _applyGrouping();
          _isLoading = false;
        });
      } else {
        setState(() {
          _pendaftarans = [];
          groupedPendaftarans = {};
          orderedDates = [];
          _isLoading = false;
        });
      }
    });
  }

  void _applyGrouping() {
    groupedPendaftarans.clear();
    _filteredPendaftarans = _pendaftarans;

    for (var item in _filteredPendaftarans) {
      final statusField = '${_currentStatus.toLowerCase()}UpdatedAt';
      final date = formatTanggal(item[statusField]);

      if (!groupedPendaftarans.containsKey(date)) {
        groupedPendaftarans[date] = [];
      }
      groupedPendaftarans[date]!.add(item);
    }

    orderedDates =
        groupedPendaftarans.keys.toList()
          ..sort((a, b) => _parseDate(b).compareTo(_parseDate(a)));
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredPendaftarans = _pendaftarans;
    } else {
      _filteredPendaftarans =
          _pendaftarans.where((item) {
            final name = (item['fullName'] ?? '').toString().toLowerCase();
            final email = (item['email'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery.toLowerCase()) ||
                email.contains(_searchQuery.toLowerCase());
          }).toList();
    }
    _applyGrouping();
  }

  String formatTanggal(dynamic tanggal) {
    if (tanggal is String && tanggal.isNotEmpty) {
      try {
        final parsed = DateFormat('dd-MM-yyyy').parse(tanggal);
        return DateFormat('dd-MM-yyyy').format(parsed);
      } catch (_) {
        return 'Tanggal Invalid';
      }
    }
    return 'Tanggal Kosong';
  }

  DateTime _parseDate(String d) {
    try {
      final parts = d.split('-');
      return DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
    } catch (_) {
      return DateTime(1970);
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushReplacementNamed('/login');
  }

  void _changeStatus(String newStatus) {
    setState(() {
      _currentStatus = newStatus;
      _isLoading = true;
      _searchQuery = '';
      _searchController.clear();
    });
    _fetchPendaftarans();
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

  Future<void> _updatePendaftaranStatus(String key, String newStatus) async {
    await FirebaseDatabase.instance
        .ref()
        .child('agent-form')
        .child(key)
        .update({
          'status': newStatus,
          '${newStatus}UpdatedAt': DateFormat(
            'dd-MM-yyyy',
          ).format(DateTime.now()),
        });
    await _fetchPendaftarans();
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Status diubah menjadi $newStatus')));
  }

  Widget _buildCard(Map pendaftaran, String key, TextStyle? baseStyle) {
    final String status = pendaftaran['status'] ?? 'Belum diproses';

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
        style: baseStyle ?? TextStyle(fontSize: 14, color: Colors.black87),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Nama        : ${pendaftaran['fullName'] ?? '-'}",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text("Email         : ${pendaftaran['email'] ?? '-'}"),
            SizedBox(height: 4),
            GestureDetector(
              onTap: () => _launchWhatsApp(pendaftaran['phone'] ?? ''),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                  children: [
                    TextSpan(text: "No. Telp     : "),
                    TextSpan(
                      text: pendaftaran['phone'] ?? '-',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 4),
            Text("Alamat      : ${pendaftaran['address'] ?? '-'}"),
            SizedBox(height: 4),
            Text("Kode Pos  : ${pendaftaran['postalCode'] ?? '-'}"),
            SizedBox(height: 4),
            Text(
              "Status       : $status",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            if (pendaftaran['note'] != null &&
                pendaftaran['note'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  "Note        : ${pendaftaran['note']}",
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            SizedBox(height: 16),

            if (status.toLowerCase() == 'pending' && _currentStatus != 'trash')
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: () => _updatePendaftaranStatus(key, 'reject'),
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
                            'Reject',
                            style: TextStyle(fontSize: 12, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 6),

                    ElevatedButton(
                      onPressed: () => _updatePendaftaranStatus(key, 'approve'),
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
                            Icons.check_circle,
                            size: 16,
                            color: Colors.white,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Approve',
                            style: TextStyle(fontSize: 12, color: Colors.white),
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
      {'label': 'QR Given', 'status': 'qr_given', 'icon': Icons.qr_code},
      {'label': 'Trash Bin', 'status': 'trash', 'icon': Icons.delete},
    ];

    return Container(
      margin: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
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
            final bool isActive = _currentStatus == item['status'];

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
                    padding: EdgeInsets.all(4),
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
        SizedBox(height: 8),
        _buildStatusMenu(),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Data Pendaftaran',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              ElevatedButton(
                onPressed: () => (),
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

        SizedBox(height: 12),

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
                          return _buildCard(item, item['key'], baseStyle);
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
      bottomNavigationBar: BottomNavBarSupervisor(currentRoute: 'status'),
    );
  }
}
