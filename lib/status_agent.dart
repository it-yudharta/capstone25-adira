// ignore_for_file: duplicate_import, unused_field, unnecessary_import, use_super_parameters, library_private_types_in_public_api, prefer_final_fields

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'order_detail_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'navbar_agent.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'circular_loading_indicator.dart';
import 'reset_password.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_screen.dart';

class StatusAgentScreen extends StatefulWidget {
  final String status;
  const StatusAgentScreen({Key? key, required this.status}) : super(key: key);

  @override
  _StatusAgentScreenState createState() => _StatusAgentScreenState();
}

class _StatusAgentScreenState extends State<StatusAgentScreen> {
  static const platform = MethodChannel('com.fundrain.adiraapp/download');
  List<Map<String, dynamic>> filteredOrders = [];
  bool isLoading = true;
  String _currentStatus = '';
  Map<String, List<Map<String, dynamic>>> groupedOrders = {};
  List<String> orderedDates = [];
  String _searchQuery = '';
  late TextEditingController _searchController;
  late FocusNode _focusNode;
  String? _selectedExportDate;
  bool _isExporting = false;
  double _exportProgress = 0.0;
  void Function(void Function())? _setExportDialogState;
  bool _exportDialogOpen = false;
  List<Map<String, dynamic>> _filteredOrders = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _focusNode = FocusNode();
    _currentStatus = widget.status;
    _fetchStatusOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _fetchStatusOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final email = user.email;
    final ref = FirebaseDatabase.instance.ref('orders');
    final snapshot = await ref.orderByChild('agentEmail').equalTo(email).get();

    if (snapshot.exists) {
      final Map data = snapshot.value as Map;
      final orders =
          data.entries.map<Map<String, dynamic>>((entry) {
            final value = Map<String, dynamic>.from(entry.value);
            value['key'] = entry.key;
            return value;
          }).toList();

      final filtered =
          orders.where((order) => order['status'] == _currentStatus).toList();

      setState(() {
        filteredOrders = filtered;
        _applySearchAndGroup();
        isLoading = false;
      });
    } else {
      setState(() {
        filteredOrders = [];
        groupedOrders = {};
        orderedDates = [];
        isLoading = false;
      });
    }
  }

  void _applySearchAndGroup() {
    final query = _searchQuery.toLowerCase().trim();

    final results =
        filteredOrders.where((order) {
          final name = (order['name'] ?? '').toString().toLowerCase();
          final phone = (order['phone'] ?? '').toString().toLowerCase();
          final tanggal = (order['tanggal'] ?? '').toString().toLowerCase();
          return name.contains(query) ||
              phone.contains(query) ||
              tanggal.contains(query);
        }).toList();

    _filteredOrders = results;

    groupedOrders.clear();

    for (var order in results) {
      final statusUpdatedAtKey = '${_currentStatus}UpdatedAt';
      final date = order[statusUpdatedAtKey] ?? order['tanggal'] ?? 'Unknown';

      if (!groupedOrders.containsKey(date)) {
        groupedOrders[date] = [];
      }
      groupedOrders[date]!.add(order);
    }

    orderedDates =
        groupedOrders.keys.toList()..sort((a, b) {
          DateTime parseDate(String d) {
            try {
              final parts = d.split('-');
              return DateTime(
                int.parse(parts[2]),
                int.parse(parts[1]),
                int.parse(parts[0]),
              );
            } catch (_) {
              return DateTime(2000);
            }
          }

          return parseDate(b).compareTo(parseDate(a));
        });
  }

  void _changeStatus(String newStatus) {
    setState(() {
      _currentStatus = newStatus;
      isLoading = true;
    });
    _fetchStatusOrders();
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

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
      (route) => false,
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Agent         : ${order['agentName'] ?? '-'}",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text("Nama         : ${order['name'] ?? '-'}"),
                SizedBox(height: 4),
                Text("Alamat       : ${order['domicile'] ?? '-'}"),
                SizedBox(height: 4),
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

                SizedBox(height: 4),
                Text("Pekerjaan  : ${order['job'] ?? '-'}"),
                SizedBox(height: 4),
                Text("Pengajuan : ${order['installment'] ?? '-'}"),
                SizedBox(height: 8),
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
              ],
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

  Widget _buildStatusMenu() {
    final List<Map<String, dynamic>> statusButtons = [
      {'label': 'Cancel', 'status': 'cancel', 'icon': 'custom_cancel_icon'},
      {'label': 'Process', 'status': 'process', 'icon': 'custom_process_icon'},
      {'label': 'Pending', 'status': 'pending', 'icon': 'custom_pending_icon'},
      {'label': 'Reject', 'status': 'reject', 'icon': 'custom_reject_icon'},
      {'label': 'Approve', 'status': 'approve', 'icon': 'custom_approve_icon'},
      {'label': 'Trash Bin', 'status': 'trash', 'icon': 'custom_bin_icon'},
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
            final bool isActive = _currentStatus == item['status'];

            return InkWell(
              onTap: () => _changeStatus(item['status']),
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
                  _applySearchAndGroup();
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
              Text(
                'Data Pengajuan',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  _showExportByStatusUpdatedDatePickerDialogAgent(
                    _currentStatus,
                  );
                },
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
              isLoading
                  ? Center(
                    child: CircularProgressIndicator(color: Color(0xFF0E5C36)),
                  )
                  : _filteredOrders.isEmpty || groupedOrders.isEmpty
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
                              _searchQuery.isEmpty
                                  ? 'No Data Found'
                                  : 'No Search Results',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No Data Found \'$_currentStatus\''
                                  : 'No Search Results',
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
                          return _buildOrderCard(order);
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

  void _showExportByStatusUpdatedDatePickerDialogAgent(String status) async {
    final updatedAtKey = '${status}UpdatedAt';
    final uniqueDates =
        filteredOrders
            .where(
              (o) =>
                  o['status'] == status &&
                  o['agentEmail'] == FirebaseAuth.instance.currentUser?.email &&
                  o[updatedAtKey] != null,
            )
            .map<String>((o) => o[updatedAtKey] as String)
            .toSet();

    final sortedDates =
        uniqueDates.toList()..sort((a, b) {
          final da = DateTime.parse(_toIsoDate(a));
          final db = DateTime.parse(_toIsoDate(b));
          return db.compareTo(da);
        });

    if (sortedDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tidak ada data dengan status "$status"')),
      );
      return;
    }

    _selectedExportDate = null;
    showDialog(
      context: context,
      builder: (_) {
        bool showError = false;
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
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
                      "Pilih Tanggal Data Pengajuan Status $status",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              if (_selectedExportDate != null) {
                                _exportOrdersByStatusUpdatedAtAgent(
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
  }

  Future<void> _exportOrdersByStatusUpdatedAtAgent(
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

    try {
      final ref = FirebaseDatabase.instance.ref("orders");
      final email = FirebaseAuth.instance.currentUser?.email;
      final key = '${status}UpdatedAt';

      final snapshot = await ref.orderByChild(key).equalTo(selectedDate).get();

      if (!snapshot.exists) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak ada data pada tanggal $selectedDate')),
        );
        return;
      }

      final List<Map<String, dynamic>> ordersToExport = [];

      for (final child in snapshot.children) {
        final data = Map<String, dynamic>.from(child.value as Map);
        if (data['status'] == status && data['agentEmail'] == email) {
          ordersToExport.add(data);
        }
      }

      if (ordersToExport.isEmpty) {
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

      final headers = <String>[
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

        final imgKeys = ['ktp', 'bpkb', 'kk', 'npwp', 'slipgaji', 'stnk'];
        for (int j = 0; j < imgKeys.length; j++) {
          final bytes = await _downloadImage(order[imgKeys[j]]);
          if (bytes != null) {
            final pic = sheet.pictures.addBase64(
              row,
              23 + j,
              base64Encode(bytes),
            );
            pic.height = 80;
            pic.width = 120;
          }
        }
      }

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = 'Folder Download';
      try {
        final savedPath = await platform.invokeMethod<String>(
          'saveFileToDownloads',
          {
            'fileName': 'pengajuan_${selectedDate}_$timestamp.xlsx',
            'bytes': bytes,
          },
        );

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
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFFF0F4F5),
          statusBarIconBrightness: Brightness.dark,
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
            PopupMenuButton<String>(
              icon: SvgPicture.asset(
                'assets/icon/agent.svg',
                width: 24,
                height: 24,
                color: Colors.black,
              ),
              onSelected: (value) {
                if (value == 'logout') {
                  _logout();
                } else if (value == 'reset') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ResetPasswordAgentScreen(),
                    ),
                  );
                }
              },
              color: Colors.white,
              itemBuilder:
                  (BuildContext context) => [
                    PopupMenuItem<String>(
                      value: 'reset',
                      child: Row(
                        children: [
                          SvgPicture.asset(
                            'assets/icon/reset_password.svg',
                            width: 18,
                            height: 18,
                            color: Color(0xFF0E5C36),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Reset Password',
                            style: TextStyle(color: Color(0xFF0E5C36)),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                      value: 'logout',
                      child: Row(
                        children: [
                          SvgPicture.asset(
                            'assets/icon/logout.svg',
                            width: 18,
                            height: 18,
                            color: Color(0xFF0E5C36),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Logout',
                            style: TextStyle(color: Color(0xFF0E5C36)),
                          ),
                        ],
                      ),
                    ),
                  ],
            ),
          ],
        ),
      ),

      body: _buildMainPage(),
      bottomNavigationBar: BottomNavBarAgent(currentRoute: ''),
    );
  }
}
