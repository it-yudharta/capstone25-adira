import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'navbar_supervisor.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
  bool _isExporting = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = '';
  late String _currentStatus;
  static const platform = MethodChannel('com.fundrain.adiraapp/download');
  String? _selectedExportDate;

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
  }

  void _showSuccessDialog(String type) {
    final isApproved = type == 'approve';
    final message =
        isApproved
            ? 'Data Approved Successfully!'
            : 'Data Rejected Successfully!';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/images/Checkmark.svg',
                    width: 80,
                    height: 80,
                  ),
                  SizedBox(height: 16),
                  Text(
                    message,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF0E5C36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Text(
                        'OK',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showRejectConfirmation(String agentKey) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reject Pendaftaran?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Pendaftaran will be rejected and\nmoved to “Reject”.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            backgroundColor: Color(0xFFE67D13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            'Back',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _updatePendaftaranStatus(agentKey, 'reject');
                            Future.delayed(Duration(milliseconds: 300), () {
                              _showSuccessDialog('reject');
                            });
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: Color(0xFF0E5C36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            'Confirm',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
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
                      onPressed: () => _showRejectConfirmation(key),
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
                      onPressed: () => _showApproveConfirmation(key),
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

  void _showApproveConfirmation(String agentKey) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Approve Pendaftaran?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Pendaftaran will be approved and\nmoved to “Approve”.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            backgroundColor: Color(0xFFE67D13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            'Back',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _updatePendaftaranStatus(agentKey, 'approve');
                            Future.delayed(Duration(milliseconds: 300), () {
                              _showSuccessDialog('approve');
                            });
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: Color(0xFF0E5C36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            'Confirm',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildStatusMenu() {
    final List<Map<String, dynamic>> statusButtons = [
      {'label': 'Cancel', 'status': 'cancel', 'icon': 'custom_cancel_icon'},
      {'label': 'Process', 'status': 'process', 'icon': 'custom_process_icon'},
      {'label': 'Pending', 'status': 'pending', 'icon': 'custom_pending_icon'},
      {'label': 'Reject', 'status': 'reject', 'icon': 'custom_reject_icon'},
      {'label': 'Approve', 'status': 'approve', 'icon': 'custom_approve_icon'},
      {'label': 'QR Given', 'status': 'qr_given', 'icon': 'custom_qr_icon'},
      {'label': 'Trash Bin', 'status': 'trash', 'icon': 'custom_bin_icon'},
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
                if (!isActive) _changeStatus(item['status']);
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
                    child: _buildSvgIcon(item['icon'], isActive),
                  ),
                  SizedBox(height: 4),
                  Text(
                    item['label'],
                    style: TextStyle(
                      fontSize: 10,
                      color: isActive ? Color(0xFF0E5C36) : Colors.black,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSvgIcon(String iconKey, bool isActive) {
    String assetPath;
    switch (iconKey) {
      case 'custom_qr_icon':
        assetPath = 'assets/icon/qr_icon.svg';
        break;
      case 'custom_approve_icon':
        assetPath = 'assets/icon/approve.svg';
        break;
      case 'custom_reject_icon':
        assetPath = 'assets/icon/reject.svg';
        break;
      case 'custom_pending_icon':
        assetPath = 'assets/icon/pending.svg';
        break;
      case 'custom_process_icon':
        assetPath = 'assets/icon/process.svg';
        break;
      case 'custom_cancel_icon':
        assetPath = 'assets/icon/cancel.svg';
        break;
      case 'custom_bin_icon':
        assetPath = 'assets/icon/bin.svg';
        break;
      default:
        return Icon(
          Icons.help,
          size: 21,
          color: isActive ? Colors.white : Color(0xFF0E5C36),
        );
    }

    return SvgPicture.asset(
      assetPath,
      width: 21,
      height: 21,
      color: isActive ? Colors.white : Color(0xFF0E5C36),
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
                onPressed:
                    () => _showExportSupervisorPendaftaranByStatusDatePicker(
                      _currentStatus,
                    ),
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
                  ? IgnorePointer(
                    ignoring: true,
                    child: SingleChildScrollView(
                      physics: NeverScrollableScrollPhysics(),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.6,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/images/EmptyState.png',
                              width: 300,
                              height: 200,
                              fit: BoxFit.contain,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'No Data Found',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'No data pendaftaran found',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  : _filteredPendaftarans.isEmpty
                  ? IgnorePointer(
                    ignoring: true,
                    child: SingleChildScrollView(
                      physics: NeverScrollableScrollPhysics(),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.6,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/images/EmptyState.png',
                              width: 300,
                              height: 200,
                              fit: BoxFit.contain,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'No Search Results',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Tidak ada hasil pencarian ditemukan',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  : _filteredPendaftarans.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/EmptyState.png',
                          width: 300,
                          height: 200,
                          fit: BoxFit.contain,
                          alignment: Alignment.topCenter,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No Search Results',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tidak ada hasil pencarian ditemukan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
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

  void _showExportSupervisorPendaftaranByStatusDatePicker(String status) async {
    final ref = FirebaseDatabase.instance.ref("agent-form");

    try {
      final snapshot = await ref.get();

      if (!snapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak ada data untuk diekspor')),
        );
        return;
      }

      final Set<String> uniqueDates = {};
      for (final child in snapshot.children) {
        final data = Map<String, dynamic>.from(child.value as Map);
        final updatedAtKey = '${status}UpdatedAt';
        final statusUpdatedAt = data[updatedAtKey];
        final agentStatus = data['status'];
        if (statusUpdatedAt != null && agentStatus == status) {
          uniqueDates.add(statusUpdatedAt);
        }
      }

      final sortedDates =
          uniqueDates.toList()..sort((a, b) {
            final dateA = DateTime.parse(_toIsoDate(a));
            final dateB = DateTime.parse(_toIsoDate(b));
            return dateB.compareTo(dateA);
          });

      if (sortedDates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak ada data dengan status "$status"')),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (_) {
          bool showError = false;
          return StatefulBuilder(
            builder: (context, setStateDialog) {
              return Dialog(
                backgroundColor: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Pilih Tanggal Data Pendaftaran Status $status",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 12),
                      Container(
                        height: 300,
                        width: double.maxFinite,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: sortedDates.length,
                          itemBuilder: (_, i) {
                            final date = sortedDates[i];
                            final isSelected = date == _selectedExportDate;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedExportDate = date;
                                });
                                setStateDialog(() {
                                  showError = false;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color:
                                        isSelected
                                            ? const Color(0xFF0E5C36)
                                            : (showError
                                                ? Colors.red
                                                : Colors.grey),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "By Date $date",
                                      style: TextStyle(
                                        color:
                                            isSelected
                                                ? const Color(0xFF0E5C36)
                                                : (showError
                                                    ? Colors.red
                                                    : Colors.black),
                                        fontWeight:
                                            isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                      ),
                                    ),
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color:
                                              isSelected
                                                  ? const Color(0xFF0E5C36)
                                                  : (showError
                                                      ? Colors.red
                                                      : Colors.black),
                                        ),
                                        color:
                                            isSelected
                                                ? const Color(0xFF0E5C36)
                                                : Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 12),
                      if (showError)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Tanggal harus dipilih",
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                backgroundColor: Color(0xFFE67D13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: TextButton(
                              onPressed: () async {
                                if (_selectedExportDate != null) {
                                  Navigator.pop(context);
                                  await _exportSupervisorPendaftaranByStatusUpdatedAt(
                                    _selectedExportDate!,
                                    status,
                                  );
                                } else {
                                  setStateDialog(() {
                                    showError = true;
                                  });
                                }
                              },
                              style: TextButton.styleFrom(
                                backgroundColor: Color(0xFF0E5C36),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(
                                'Export',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengambil tanggal: $e')));
    }
  }

  Future<void> _exportSupervisorPendaftaranByStatusUpdatedAt(
    String selectedDate,
    String status,
  ) async {
    setState(() => _isExporting = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator()),
    );

    final ref = FirebaseDatabase.instance.ref("agent-form");

    try {
      final updatedAtKey = '${status}UpdatedAt';
      final snapshot =
          await ref.orderByChild(updatedAtKey).equalTo(selectedDate).get();

      final List<Map> agentsToExport = [];

      for (final child in snapshot.children) {
        final data = Map<String, dynamic>.from(child.value as Map);
        if (data['status'] == status) {
          data['key'] = child.key;
          agentsToExport.add(data);
        }
      }

      if (agentsToExport.isEmpty) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tidak ada data "$status" di tanggal $selectedDate'),
          ),
        );
        return;
      }

      final workbook = xlsio.Workbook();
      final sheet = workbook.worksheets[0];

      final headers = [
        'Tanggal',
        'Status',
        'Tanggal Cancel',
        'Tanggal Process',
        'Tanggal Pending',
        'Tanggal Reject',
        'Tanggal Approve',
        'Tanggal QR Given',
        'Nama',
        'Email',
        'No. Telepon',
        'Alamat',
        'Kode Pos',
        'Foto KK',
        'Foto KTP',
        'Foto NPWP',
      ];

      for (int col = 0; col < headers.length; col++) {
        sheet.getRangeByIndex(1, col + 1).setText(headers[col]);
      }

      for (int col in [14, 15, 16]) {
        sheet.getRangeByIndex(1, col).columnWidth = 20;
      }

      for (int i = 0; i < agentsToExport.length; i++) {
        final agent = Map<String, dynamic>.from(agentsToExport[i]);
        final row = i + 2;

        sheet.getRangeByIndex(row, 1).rowHeight = 80;
        sheet.getRangeByIndex(row, 1).setText(agent['tanggal'] ?? '');
        sheet.getRangeByIndex(row, 2).setText(agent['status'] ?? '');

        sheet.getRangeByIndex(row, 3).setText(agent['cancelUpdatedAt'] ?? '');
        sheet.getRangeByIndex(row, 4).setText(agent['processUpdatedAt'] ?? '');
        sheet.getRangeByIndex(row, 5).setText(agent['pendingUpdatedAt'] ?? '');
        sheet.getRangeByIndex(row, 6).setText(agent['rejectUpdatedAt'] ?? '');
        sheet.getRangeByIndex(row, 7).setText(agent['approveUpdatedAt'] ?? '');
        sheet.getRangeByIndex(row, 8).setText(agent['qr_givenUpdatedAt'] ?? '');

        sheet.getRangeByIndex(row, 9).setText(agent['fullName'] ?? '');
        sheet.getRangeByIndex(row, 10).setText(agent['email'] ?? '');
        sheet.getRangeByIndex(row, 11).setText(agent['phone'] ?? '');
        sheet.getRangeByIndex(row, 12).setText(agent['address'] ?? '');
        sheet.getRangeByIndex(row, 13).setText(agent['postalCode'] ?? '');

        final kkImage = await _downloadImage(agent['kk']);
        final ktpImage = await _downloadImage(agent['ktp']);
        final npwpImage = await _downloadImage(agent['npwp']);

        if (kkImage != null) {
          final pic = sheet.pictures.addBase64(row, 14, base64Encode(kkImage));
          pic.height = 80;
          pic.width = 120;
        }
        if (ktpImage != null) {
          final pic = sheet.pictures.addBase64(row, 15, base64Encode(ktpImage));
          pic.height = 80;
          pic.width = 120;
        }
        if (npwpImage != null) {
          final pic = sheet.pictures.addBase64(
            row,
            16,
            base64Encode(npwpImage),
          );
          pic.height = 80;
          pic.width = 120;
        }
      }

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final savedPath = await platform.invokeMethod<String>(
        'saveFileToDownloads',
        {
          'fileName': 'supervisor_pendaftaran_${selectedDate}_$timestamp.xlsx',
          'bytes': bytes,
        },
      );

      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _isExporting = false);

      if (savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File berhasil disimpan di $savedPath')),
        );
      }
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengekspor: $e')));
    }
  }

  String _toIsoDate(String date) {
    try {
      final parts = date.split('-');
      return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
    } catch (_) {
      return date;
    }
  }

  Future<Uint8List?> _downloadImage(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(url));
      return response.bodyBytes;
    } catch (e) {
      print('Gagal download gambar: $e');
      return null;
    }
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
