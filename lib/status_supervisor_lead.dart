// ignore_for_file: duplicate_import, unused_field, unused_local_variable, library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use, sized_box_for_whitespace, unnecessary_to_list_in_spreads, avoid_print

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'navbar_supervisor.dart';
import 'package:flutter/services.dart';
import 'order_detail_screen.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:http/http.dart' as http;
import 'circular_loading_indicator.dart';
import 'pendaftaran_detail_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';

class StatusSupervisorLead extends StatefulWidget {
  final String status;
  final String type;

  const StatusSupervisorLead({
    super.key,
    required this.status,
    required this.type,
  });

  @override
  _StatusSupervisorLeadState createState() => _StatusSupervisorLeadState();
}

class _StatusSupervisorLeadState extends State<StatusSupervisorLead> {
  static const platform = MethodChannel('com.fundrain.adiraapp/download');
  final _database = FirebaseDatabase.instance.ref();
  bool _isLoading = false;
  List<Map<dynamic, dynamic>> _filteredData = [];
  Map<String, Map<String, List<Map<String, dynamic>>>> groupedData = {};
  late String _currentStatus;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = '';
  String _selectedType = 'semua';
  String? _selectedExportDate;
  void Function(void Function())? _setExportDialogState;
  double _exportProgress = 0;
  bool _isExporting = false;

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      setState(() {
        groupedData = groupByDateAndSource(_filteredData);
      });
      return;
    }

    final filtered =
        _filteredData.where((item) {
          final name = item['name'] ?? item['fullName'] ?? '';
          final email = item['email'] ?? '';
          final phone = item['phone'] ?? '';
          return name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              phone.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

    setState(() {
      groupedData = groupByDateAndSource(filtered);
    });
  }

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.status;
    _fetchFilteredData();
  }

  Future<void> _fetchFilteredData() async {
    setState(() => _isLoading = true);
    final List<Map<dynamic, dynamic>> result = [];

    if (_selectedType == 'pengajuan' || _selectedType == 'semua') {
      final ordersSnapshot = await _database.child('orders').get();
      if (ordersSnapshot.exists) {
        final data = ordersSnapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final status = value['status'];
          final isTrash = value['trash'] == true;
          final isLead = value['lead'] == true;
          if (_currentStatus == 'trash') {
            if (isLead && isTrash) {
              value['key'] = key;
              value['source'] = 'pengajuan';
              result.add(Map<String, dynamic>.from(value));
            }
          } else {
            if (status == _currentStatus && isLead && !isTrash) {
              value['key'] = key;
              value['source'] = 'pengajuan';
              result.add(Map<String, dynamic>.from(value));
            }
          }
        });
      }
    }

    if (_selectedType == 'pendaftaran' || _selectedType == 'semua') {
      final agentsSnapshot = await _database.child('agent-form').get();
      if (agentsSnapshot.exists) {
        final data = agentsSnapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final status = value['status'];
          final isTrash = value['trash'] == true;
          final isLead = value['lead'] == true;

          if (_currentStatus == 'trash') {
            if (isLead && isTrash) {
              value['key'] = key;
              value['source'] = 'pendaftaran';
              result.add(Map<String, dynamic>.from(value));
            }
          } else {
            if (status == _currentStatus && isLead && !isTrash) {
              value['key'] = key;
              value['source'] = 'pendaftaran';
              result.add(Map<String, dynamic>.from(value));
            }
          }
        });
      }
    }

    setState(() {
      _filteredData = result;
      groupedData = groupByDateAndSource(_filteredData);
      _isLoading = false;
    });
  }

  Map<String, Map<String, List<Map<String, dynamic>>>> groupByDateAndSource(
    List<Map> data,
  ) {
    final Map<String, Map<String, List<Map<String, dynamic>>>> grouped = {};
    final String statusDateField = '${_currentStatus}UpdatedAt';

    for (var item in data) {
      final source = item['source'] ?? 'pengajuan';
      final tanggal = item[statusDateField] ?? 'Tanggal tidak diketahui';

      grouped.putIfAbsent(tanggal, () => {});
      grouped[tanggal]!.putIfAbsent(source, () => []);
      grouped[tanggal]![source]!.add(Map<String, dynamic>.from(item));
    }

    return grouped;
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
      (route) => false,
    );
  }

  String normalizePhoneNumber(String phone) {
    if (phone.startsWith('0')) {
      return '62${phone.substring(1)}';
    }
    return phone;
  }

  Future<void> _launchWhatsApp(String phoneNumber) async {
    final normalizedPhone = normalizePhoneNumber(phoneNumber);
    final uri = Uri.parse('https://wa.me/$normalizedPhone');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Tidak dapat membuka WhatsApp')));
    }
  }

  void _changeStatus(String newStatus) {
    setState(() {
      _currentStatus = newStatus;
      _fetchFilteredData();
    });
  }

  Future<void> _updateSupervisorLeadStatus(String key, String newStatus) async {
    final now = DateFormat('dd-MM-yyyy').format(DateTime.now());

    final refOrders = FirebaseDatabase.instance.ref('orders/$key');
    final refForms = FirebaseDatabase.instance.ref('agent-form/$key');

    final snapOrders = await refOrders.get();
    final snapForms = await refForms.get();

    if (snapOrders.exists) {
      await refOrders.update({
        'status': newStatus,
        '${newStatus}UpdatedAt': now,
      });
    } else if (snapForms.exists) {
      await refForms.update({
        'status': newStatus,
        '${newStatus}UpdatedAt': now,
      });
    }

    await _fetchFilteredData();
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

  void _showRejectConfirmation(String key) {
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
                    'Reject Data?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Data will be rejected and\nmoved to “Reject”.',
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
                            _updateSupervisorLeadStatus(key, 'reject');
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

  void _showApproveConfirmation(String key) {
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
                    'Approve Data?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Data will be approved and\nmoved to “Approve”.',
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
                            _updateSupervisorLeadStatus(key, 'approve');
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

  Widget _buildCard(Map data) {
    final String status = data['status'] ?? 'Belum diproses';
    final String phone = data['phone'] ?? '-';
    final String key = data['key'];
    final bool isLead = data['lead'] == true;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PendaftaranDetailScreen(agentData: data),
          ),
        );
      },
      child: Container(
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
        child: Stack(
          children: [
            DefaultTextStyle.merge(
              style: TextStyle(fontSize: 14, color: Colors.black87),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Nama        : ${data['fullName'] ?? data['name'] ?? '-'}",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text("Email         : ${data['email'] ?? '-'}"),
                  SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _launchWhatsApp(phone),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(color: Colors.black87),
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
                  Text(
                    "Alamat      : ${data['address'] ?? data['domicile'] ?? '-'}",
                  ),
                  SizedBox(height: 4),
                  Text("Kode Pos  : ${data['postalCode'] ?? '-'}"),
                  SizedBox(height: 4),
                  Text(
                    "Status       : $status",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (data['note'] != null &&
                      data['note'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        "Note          : ${data['note']}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  SizedBox(height: 16),
                  if (status.toLowerCase() == 'pending' &&
                      widget.status != 'trash')
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
                                Icon(
                                  Icons.cancel,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Reject',
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
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.only(top: 8, right: 8),
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
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map order) {
    final phone = order['phone'] ?? '-';
    final status = order['status'] ?? 'Belum diproses';
    final isLead = order['lead'] == true;
    final key = order['key'];

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => OrderDetailScreen(orderData: order, orderKey: key),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 4)],
        ),
        child: Stack(
          children: [
            DefaultTextStyle.merge(
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Agent         : ${order['agentName'] ?? '-'}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text("Nama         : ${order['name'] ?? '-'}"),
                  const SizedBox(height: 4),
                  Text("Alamat       : ${order['domicile'] ?? '-'}"),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _launchWhatsApp(phone),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        children: [
                          const TextSpan(text: "No. Telp      : "),
                          TextSpan(
                            text: phone,
                            style: const TextStyle(color: Colors.blue),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text("Pekerjaan  : ${order['job'] ?? '-'}"),
                  const SizedBox(height: 4),
                  Text("Pengajuan : ${order['item'] ?? '-'}"),
                  const SizedBox(height: 8),
                  Text(
                    "Status        : $status",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (order['note'] != null &&
                      order['note'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        "Note           : ${order['note']}",
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (status.toLowerCase() == 'pending' &&
                      widget.status != 'trash')
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            onPressed:
                                () => _showRejectConfirmationPengajuan(key),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0E5C36),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.cancel,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Reject',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton(
                            onPressed:
                                () => _showApproveConfirmationPengajuan(key),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0E5C36),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Approve',
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
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 8),
                  child: Transform.scale(
                    scaleY: 1.3,
                    scaleX: 1.0,
                    child: const Icon(
                      Icons.bookmark,
                      size: 24,
                      color: Color(0xFF0E5C36),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateOrderStatusPengajuan(String key, String newStatus) async {
    final now = DateFormat('dd-MM-yyyy').format(DateTime.now());

    final refOrders = FirebaseDatabase.instance.ref('orders/$key');
    final refForms = FirebaseDatabase.instance.ref('agent-form/$key');

    final snapOrders = await refOrders.get();
    final snapForms = await refForms.get();

    if (snapOrders.exists) {
      await refOrders.update({
        'status': newStatus,
        '${newStatus}UpdatedAt': now,
      });
    } else if (snapForms.exists) {
      await refForms.update({
        'status': newStatus,
        '${newStatus}UpdatedAt': now,
      });
    }

    await _fetchFilteredData();
  }

  void _showRejectConfirmationPengajuan(String key) {
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
                    'Reject Data?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Data will be rejected and\nmoved to “Reject”.',
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
                          onPressed: () async {
                            Navigator.pop(context);
                            await _updateOrderStatusPengajuan(key, 'reject');
                            _showSuccessDialog('reject');
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

  void _showApproveConfirmationPengajuan(String key) {
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
                    'Approve Data?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Data will be approved and\nmoved to “Approve”.',
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
                          onPressed: () async {
                            Navigator.pop(context);
                            await _updateOrderStatusPengajuan(key, 'approve');
                            _showSuccessDialog('approve');
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

  Widget _buildStatusMenu() {
    final List<Map<String, dynamic>> statusButtons = [
      {'label': 'Cancel', 'status': 'cancel', 'icon': 'custom_cancel_icon'},
      {'label': 'Process', 'status': 'process', 'icon': 'custom_process_icon'},
      {'label': 'Pending', 'status': 'pending', 'icon': 'custom_pending_icon'},
      {'label': 'Reject', 'status': 'reject', 'icon': 'custom_reject_icon'},
      {'label': 'Approve', 'status': 'approve', 'icon': 'custom_approve_icon'},
      {'label': 'QR Given', 'status': 'qr_given', 'icon': 'custom_qr_icon'},
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
            children: [
              Row(
                children: [
                  PopupMenuButton<String>(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    offset: Offset(0, 40),
                    onSelected: (value) {
                      setState(() {
                        _selectedType = value;
                        _fetchFilteredData();
                      });
                    },
                    itemBuilder:
                        (BuildContext context) => [
                          PopupMenuItem<String>(
                            value: 'pengajuan',
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Pengajuan',
                                    style: TextStyle(
                                      color:
                                          _selectedType == 'pengajuan'
                                              ? Color(0xFF0E5C36)
                                              : Colors.black,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 1.2,
                                    ),
                                    color:
                                        _selectedType == 'pengajuan'
                                            ? Color(0xFF0E5C36)
                                            : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuDivider(),
                          PopupMenuItem<String>(
                            value: 'pendaftaran',
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Pendaftaran',
                                    style: TextStyle(
                                      color:
                                          _selectedType == 'pendaftaran'
                                              ? Color(0xFF0E5C36)
                                              : Colors.black,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 1.2,
                                    ),
                                    color:
                                        _selectedType == 'pendaftaran'
                                            ? Color(0xFF0E5C36)
                                            : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                    child: SvgPicture.asset(
                      'assets/icon/filter.svg',
                      color:
                          _selectedType == 'semua'
                              ? Colors.black
                              : Color(0xFF0E5C36),
                    ),
                  ),
                  SizedBox(width: 8),
                  if (_selectedType != 'semua')
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _selectedType[0].toUpperCase() +
                                _selectedType.substring(1),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedType = 'semua';
                                _fetchFilteredData();
                              });
                            },
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              ElevatedButton(
                onPressed:
                    () => _showExportByStatusDateDialogLead(_currentStatus),
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
                  ? Center(
                    child: CircularProgressIndicator(color: Color(0xFF0E5C36)),
                  )
                  : groupedData.isEmpty
                  ? (_searchQuery.isEmpty
                      ? _buildEmptyState()
                      : _buildNoSearchResult())
                  : ListView(
                    children:
                        groupedData.entries.map((entry) {
                          final tanggal = entry.key;
                          final sources = entry.value;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  4,
                                ),
                                child: Text(
                                  'Date: $tanggal',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              ...sources.entries.expand((sourceEntry) {
                                return sourceEntry.value.map((data) {
                                  final source = data['source'];
                                  if (source == 'pengajuan') {
                                    return _buildOrderCard(data);
                                  } else {
                                    return _buildCard(data);
                                  }
                                });
                              }).toList(),
                            ],
                          );
                        }).toList(),
                  ),
        ),
      ],
    );
  }

  void _showExportByStatusDateDialogLead(String selectedStatus) async {
    try {
      final pengajuanRef = FirebaseDatabase.instance.ref('orders');
      final pendaftaranRef = FirebaseDatabase.instance.ref('agent-form');

      final Set<String> uniqueDates = {};
      final updatedAtKey = '${selectedStatus}UpdatedAt';

      if (_selectedType == 'pengajuan' || _selectedType == 'semua') {
        final pengajuanSnap = await pengajuanRef.get();
        for (final child in pengajuanSnap.children) {
          final data = Map<String, dynamic>.from(child.value as Map);
          if (data['status'] == selectedStatus &&
              data[updatedAtKey] != null &&
              data['lead'] == true) {
            uniqueDates.add(data[updatedAtKey]);
          }
        }
      }

      if (_selectedType == 'pendaftaran' || _selectedType == 'semua') {
        final pendaftaranSnap = await pendaftaranRef.get();
        for (final child in pendaftaranSnap.children) {
          final data = Map<String, dynamic>.from(child.value as Map);
          if (data['status'] == selectedStatus &&
              data[updatedAtKey] != null &&
              data['lead'] == true) {
            uniqueDates.add(data[updatedAtKey]);
          }
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
          SnackBar(content: Text('Tidak ada data status "$selectedStatus"')),
        );
        return;
      }

      _selectedExportDate = null;

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
                        "Pilih Tanggal Data Status $selectedStatus Yang Ingin Diexport",
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
                          itemCount: sortedDates.length,
                          itemBuilder: (_, i) {
                            final date = sortedDates[i];
                            final isSelected = date == _selectedExportDate;

                            return GestureDetector(
                              onTap: () {
                                setStateDialog(() {
                                  _selectedExportDate = date;
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
                              onPressed: () {
                                if (_selectedExportDate != null) {
                                  _exportLeadStatusByDate(
                                    _selectedExportDate!,
                                    selectedStatus,
                                    _selectedType,
                                  );
                                } else {
                                  setStateDialog(() => showError = true);
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
      ).showSnackBar(SnackBar(content: Text('Gagal mengambil data: $e')));
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

  Future<void> _exportLeadStatusByDate(
    String selectedDate,
    String status,
    String tipe,
  ) async {
    if (tipe == 'pengajuan') {
      await _exportLeadPengajuanByDateAndStatus(selectedDate, status);
    } else if (tipe == 'pendaftaran') {
      await _exportLeadPendaftaranByDateAndStatus(selectedDate, status);
    } else if (tipe == 'semua') {
      await _exportLeadPengajuanDanPendaftaranByStatusAndDate(
        selectedDate,
        status,
      );
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

  Future<void> _exportLeadPengajuanByDateAndStatus(
    String selectedDate,
    String status,
  ) async {
    setState(() => _isExporting = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            _setExportDialogState = setStateDialog;
            return Dialog(
              backgroundColor: Colors.transparent,
              child: SizedBox(
                width: 120,
                height: 120,
                child: CircularExportIndicator(progress: _exportProgress),
              ),
            );
          },
        );
      },
    );

    final ref = FirebaseDatabase.instance.ref("orders");

    try {
      final updatedAtKey = '${status}UpdatedAt';
      final snapshot =
          await ref.orderByChild(updatedAtKey).equalTo(selectedDate).get();

      if (!snapshot.exists) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tidak ada data "$status" pada tanggal $selectedDate',
            ),
          ),
        );
        return;
      }

      final List<Map> ordersToExport = [];

      for (final child in snapshot.children) {
        final data = Map<String, dynamic>.from(child.value as Map);
        if (data['status'] == status && data['lead'] == true) {
          data['key'] = child.key;
          ordersToExport.add(data);
        }
      }

      if (ordersToExport.isEmpty) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tidak ada data lead "$status" di tanggal $selectedDate',
            ),
          ),
        );
        return;
      }

      final workbook = xlsio.Workbook();
      final sheet = workbook.worksheets[0];

      final headers = [
        'Tanggal Pengajuan',
        'Status',
        'Tanggal Cancel',
        'Tanggal Process',
        'Tanggal Pending',
        'Tanggal Reject',
        'Tanggal Approve',
        'Nama',
        'Email',
        'No. Telephone',
        'Pekerjaan',
        'Pendapatan',
        'Item',
        'Merk',
        'Nominal Pengajuan',
        'Angsuran Lain',
        'DP',
        'Domisili',
        'Kode Pos',
        'Nama Agent',
        'Email Agent',
        'No. Telephone Agent',
        'Foto KTP',
        'Foto BPKB',
        'Foto KK',
        'Foto NPWP',
        'Foto Slip Gaji',
        'Foto STNK',
      ];

      for (int col = 0; col < headers.length; col++) {
        sheet.getRangeByIndex(1, col + 1).setText(headers[col]);
      }

      for (int col = 19; col <= 22; col++) {
        sheet.getRangeByIndex(1, col).columnWidth = 20;
      }

      for (int i = 0; i < ordersToExport.length; i++) {
        final order = ordersToExport[i];
        final row = i + 2;

        _setExportDialogState?.call(() {
          _exportProgress = (i + 1) / ordersToExport.length;
        });

        sheet.getRangeByIndex(row, 1).rowHeight = 80;
        sheet.getRangeByIndex(row, 1).setText(order['tanggal'] ?? '');
        sheet.getRangeByIndex(row, 2).setText(order['status'] ?? '');
        sheet.getRangeByIndex(row, 3).setText(order['cancelUpdatedAt'] ?? '');
        sheet.getRangeByIndex(row, 4).setText(order['processUpdatedAt'] ?? '');
        sheet.getRangeByIndex(row, 5).setText(order['pendingUpdatedAt'] ?? '');
        sheet.getRangeByIndex(row, 6).setText(order['rejectUpdatedAt'] ?? '');
        sheet.getRangeByIndex(row, 7).setText(order['approveUpdatedAt'] ?? '');
        sheet.getRangeByIndex(row, 8).setText(order['name'] ?? '');
        sheet.getRangeByIndex(row, 9).setText(order['email'] ?? '');
        sheet.getRangeByIndex(row, 10).setText(order['phone'] ?? '');
        sheet.getRangeByIndex(row, 11).setText(order['job'] ?? '');
        sheet.getRangeByIndex(row, 12).setText(order['income'] ?? '');
        sheet.getRangeByIndex(row, 13).setText(order['item'] ?? '');
        sheet.getRangeByIndex(row, 14).setText(order['merk'] ?? '');
        sheet.getRangeByIndex(row, 15).setText(order['nominal'] ?? '');
        sheet.getRangeByIndex(row, 16).setText(order['installment'] ?? '');
        sheet.getRangeByIndex(row, 17).setText(order['dp'] ?? '');
        sheet.getRangeByIndex(row, 18).setText(order['domicile'] ?? '');
        sheet.getRangeByIndex(row, 19).setText(order['postalCode'] ?? '');
        sheet.getRangeByIndex(row, 20).setText(order['agentName'] ?? '');
        sheet.getRangeByIndex(row, 21).setText(order['agentEmail'] ?? '');
        sheet.getRangeByIndex(row, 22).setText(order['agentPhone'] ?? '');

        final ktpBytes = await _downloadImage(order['ktp']);
        final bpkbBytes = await _downloadImage(order['bpkb']);
        final kkBytes = await _downloadImage(order['kk']);
        final npwpBytes = await _downloadImage(order['npwp']);
        final slipGajiBytes = await _downloadImage(order['slipgaji']);
        final stnkBytes = await _downloadImage(order['stnk']);

        if (ktpBytes != null) {
          sheet.pictures.addBase64(row, 23, base64Encode(ktpBytes))
            ..height = 80
            ..width = 120;
        }
        if (bpkbBytes != null) {
          sheet.pictures.addBase64(row, 24, base64Encode(bpkbBytes))
            ..height = 80
            ..width = 120;
        }
        if (kkBytes != null) {
          sheet.pictures.addBase64(row, 25, base64Encode(kkBytes))
            ..height = 80
            ..width = 120;
        }
        if (npwpBytes != null) {
          sheet.pictures.addBase64(row, 26, base64Encode(npwpBytes))
            ..height = 80
            ..width = 120;
        }
        if (slipGajiBytes != null) {
          sheet.pictures.addBase64(row, 27, base64Encode(slipGajiBytes))
            ..height = 80
            ..width = 120;
        }
        if (stnkBytes != null) {
          sheet.pictures.addBase64(row, 28, base64Encode(stnkBytes))
            ..height = 80
            ..width = 120;
        }
      }

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = 'Folder Download';
      try {
        final savedPath = await platform
            .invokeMethod<String>('saveFileToDownloads', {
              'fileName': 'lead_pengajuan_${selectedDate}_$timestamp.xlsx',
              'bytes': bytes,
            });

        if (savedPath != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('File berhasil disimpan di $savedPath')),
          );
        }
      } on PlatformException catch (e) {
        print("Gagal menyimpan file: ${e.message}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan file: ${e.message}')),
        );
      }

      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File berhasil disimpan di $filePath')),
      );
    } catch (e, stacktrace) {
      print('Error export: $e');
      print(stacktrace);
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengekspor: $e')));
    }
  }

  Future<void> _exportLeadPendaftaranByDateAndStatus(
    String selectedDate,
    String status,
  ) async {
    setState(() => _isExporting = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            _setExportDialogState = setStateDialog;
            return Dialog(
              backgroundColor: Colors.transparent,
              child: SizedBox(
                width: 120,
                height: 120,
                child: CircularExportIndicator(progress: _exportProgress),
              ),
            );
          },
        );
      },
    );

    final ref = FirebaseDatabase.instance.ref("agent-form");

    try {
      final updatedAtKey = '${status}UpdatedAt';
      final snapshot =
          await ref.orderByChild(updatedAtKey).equalTo(selectedDate).get();

      final List<Map> agentsToExport = [];

      for (final child in snapshot.children) {
        final data = Map<String, dynamic>.from(child.value as Map);
        if (data['status'] == status && data['lead'] == true) {
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
        _setExportDialogState?.call(() {
          _exportProgress = (i + 1) / agentsToExport.length;
        });

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

      final savedPath = await platform
          .invokeMethod<String>('saveFileToDownloads', {
            'fileName': 'lead_pendaftaran_${selectedDate}_$timestamp.xlsx',
            'bytes': bytes,
          });

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

  Future<void> _exportLeadPengajuanDanPendaftaranByStatusAndDate(
    String selectedDate,
    String status,
  ) async {
    _exportProgress = 0;
    setState(() => _isExporting = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            _setExportDialogState = setStateDialog;
            return Dialog(
              backgroundColor: Colors.transparent,
              child: SizedBox(
                width: 120,
                height: 120,
                child: CircularExportIndicator(progress: _exportProgress),
              ),
            );
          },
        );
      },
    );

    final ordersRef = FirebaseDatabase.instance.ref('orders');
    final agentsRef = FirebaseDatabase.instance.ref('agent-form');
    final updatedAtKey = '${status}UpdatedAt';

    try {
      final workbook = xlsio.Workbook();
      final sheet = workbook.worksheets[0];

      final headers = [
        'Tipe',
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
        'Alamat/Domisili',
        'Kode Pos',
        'Foto KK',
        'Foto KTP',
        'Foto NPWP',
      ];

      for (int col = 0; col < headers.length; col++) {
        sheet.getRangeByIndex(1, col + 1).setText(headers[col]);
      }

      for (int col in [15, 16, 17]) {
        sheet.getRangeByIndex(1, col).columnWidth = 20;
      }

      int row = 2;

      final ordersSnap =
          await ordersRef
              .orderByChild(updatedAtKey)
              .equalTo(selectedDate)
              .get();
      for (final child in ordersSnap.children) {
        final data = Map<String, dynamic>.from(child.value as Map);
        if (data['status'] == status && data['lead'] == true) {
          _setExportDialogState?.call(() {
            _exportProgress += 0.5 / ordersSnap.children.length;
          });

          sheet.getRangeByIndex(row, 1).rowHeight = 80;
          sheet.getRangeByIndex(row, 1).setText('pengajuan');
          sheet.getRangeByIndex(row, 2).setText(data['tanggal'] ?? '');
          sheet.getRangeByIndex(row, 3).setText(data['status'] ?? '');
          sheet.getRangeByIndex(row, 4).setText(data['cancelUpdatedAt'] ?? '');
          sheet.getRangeByIndex(row, 5).setText(data['processUpdatedAt'] ?? '');
          sheet.getRangeByIndex(row, 6).setText(data['pendingUpdatedAt'] ?? '');
          sheet.getRangeByIndex(row, 7).setText(data['rejectUpdatedAt'] ?? '');
          sheet.getRangeByIndex(row, 8).setText(data['approveUpdatedAt'] ?? '');
          sheet.getRangeByIndex(row, 9).setText(data['name'] ?? '');
          sheet.getRangeByIndex(row, 10).setText(data['email'] ?? '');
          sheet.getRangeByIndex(row, 11).setText(data['phone'] ?? '');
          sheet.getRangeByIndex(row, 12).setText(data['domicile'] ?? '');
          sheet.getRangeByIndex(row, 13).setText(data['postalCode'] ?? '');

          final kk = await _downloadImage(data['kk']);
          final ktp = await _downloadImage(data['ktp']);
          final npwp = await _downloadImage(data['npwp']);

          if (kk != null) {
            sheet.pictures.addBase64(row, 14, base64Encode(kk))
              ..height = 80
              ..width = 120;
          }
          if (ktp != null) {
            sheet.pictures.addBase64(row, 15, base64Encode(ktp))
              ..height = 80
              ..width = 120;
          }
          if (npwp != null) {
            sheet.pictures.addBase64(row, 16, base64Encode(npwp))
              ..height = 80
              ..width = 120;
          }

          row++;
        }
      }
      final agentsSnap =
          await agentsRef
              .orderByChild(updatedAtKey)
              .equalTo(selectedDate)
              .get();
      for (final child in agentsSnap.children) {
        final data = Map<String, dynamic>.from(child.value as Map);
        if (data['status'] == status) {
          _setExportDialogState?.call(() {
            _exportProgress += 0.5 / agentsSnap.children.length;
          });

          sheet.getRangeByIndex(row, 1).rowHeight = 80;
          sheet.getRangeByIndex(row, 1).setText('pendaftaran');
          sheet.getRangeByIndex(row, 2).setText(data['tanggal'] ?? '');
          sheet.getRangeByIndex(row, 3).setText(data['status'] ?? '');
          sheet.getRangeByIndex(row, 4).setText(data['cancelUpdatedAt'] ?? '');
          sheet.getRangeByIndex(row, 5).setText(data['processUpdatedAt'] ?? '');
          sheet.getRangeByIndex(row, 6).setText(data['pendingUpdatedAt'] ?? '');
          sheet.getRangeByIndex(row, 7).setText(data['rejectUpdatedAt'] ?? '');
          sheet.getRangeByIndex(row, 8).setText(data['approveUpdatedAt'] ?? '');
          sheet.getRangeByIndex(row, 9).setText(data['fullName'] ?? '');
          sheet.getRangeByIndex(row, 10).setText(data['email'] ?? '');
          sheet.getRangeByIndex(row, 11).setText(data['phone'] ?? '');
          sheet.getRangeByIndex(row, 12).setText(data['address'] ?? '');
          sheet.getRangeByIndex(row, 13).setText(data['postalCode'] ?? '');

          final kk = await _downloadImage(data['kk']);
          final ktp = await _downloadImage(data['ktp']);
          final npwp = await _downloadImage(data['npwp']);

          if (kk != null) {
            sheet.pictures.addBase64(row, 14, base64Encode(kk))
              ..height = 80
              ..width = 120;
          }
          if (ktp != null) {
            sheet.pictures.addBase64(row, 15, base64Encode(ktp))
              ..height = 80
              ..width = 120;
          }
          if (npwp != null) {
            sheet.pictures.addBase64(row, 16, base64Encode(npwp))
              ..height = 80
              ..width = 120;
          }

          row++;
        }
      }

      if (row == 2) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tidak ada data lead "$status" pada $selectedDate'),
          ),
        );
        return;
      }

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final savedPath = await platform.invokeMethod<String>(
        'saveFileToDownloads',
        {
          'fileName': 'lead_semua_${selectedDate}_$timestamp.xlsx',
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

  Widget _buildNoSearchResult() {
    return IgnorePointer(
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
                'No Search Result',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade500,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'No data lead found',
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
    );
  }

  Widget _buildEmptyState() {
    return IgnorePointer(
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
                'No data lead found',
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
              icon: SvgPicture.asset(
                'assets/icon/logout.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(Colors.black, BlendMode.srcIn),
              ),
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
