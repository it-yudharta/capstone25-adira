import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'status_pengajuan_screen.dart';
import 'login_screen.dart';
import 'order_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';

const platform = MethodChannel('com.fundrain.resellerapp/download');

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
  bool _isExporting = false;
  final FocusNode _focusNode = FocusNode();

  List<String> get orderedDates {
    final grouped = groupedOrders;
    final dates = grouped.keys.toList();

    dates.sort((a, b) {
      DateTime? dateA, dateB;

      try {
        dateA = DateFormat('d-M-yyyy').parseStrict(a);
      } catch (_) {
        dateA = null;
      }
      try {
        dateB = DateFormat('d-M-yyyy').parseStrict(b);
      } catch (_) {
        dateB = null;
      }

      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
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
        value['key'] = key;
        loadedOrders.add(value);
      });

      setState(() {
        _orders =
            loadedOrders.where((order) {
              return order['status'] == null ||
                  order['status'] == 'Belum diproses';
            }).toList();
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
              final tanggal = (order['tanggal'] ?? '').toString().toLowerCase();
              return name.contains(query) ||
                  email.contains(query) ||
                  agentName.contains(query) ||
                  tanggal.contains(query);
            }).toList();
  }

  Map<String, List<Map>> _groupOrdersByDate(List<Map> orders) {
    final Map<String, List<Map>> grouped = {};
    for (var order in orders) {
      final dateStr = order['tanggal'];
      String dateKey;
      try {
        if (dateStr == null || dateStr.isEmpty) throw FormatException();
        DateFormat('d-M-yyyy').parseStrict(dateStr);
        dateKey = dateStr;
      } catch (_) {
        dateKey = 'Tanggal tidak diketahui';
      }
      grouped.putIfAbsent(dateKey, () => []).add(order);
    }
    return grouped;
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

  void _updateOrderStatus(String orderKey, String newStatus) async {
    final now = DateTime.now();
    final formattedDate = DateFormat('dd-MM-yyyy').format(now);

    try {
      await _database.child(orderKey).update({
        'status': newStatus,
        'statusUpdatedAt': formattedDate,
      });
      _fetchOrders();
    } catch (e) {
      print("Gagal memperbarui status: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memperbarui status')));
    }
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
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed:
                              () => _updateOrderStatus(order['key'], 'cancel'),
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
                          onPressed:
                              () => _updateOrderStatus(order['key'], 'process'),
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
                                Icons.hourglass_bottom,
                                size: 16,
                                color: Colors.white,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Process',
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
            return InkWell(
              onTap: () {
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
                      color: Color(0xFF0E5C36),
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
                onPressed: _confirmDeleteAllToTrash,
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
                    Icon(Icons.delete_outline, size: 16, color: Colors.white),
                    SizedBox(height: 4),
                    Text(
                      'Delete All',
                      style: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              ElevatedButton(
                onPressed: _showExportDatePickerDialog,
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

  void _confirmDeleteAllToTrash() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Hapus Semua?'),
            content: Text('Yakin ingin menghapus semua data (non-lead)?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Batal'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteAllToTrash();
                },
                child: Text('Ya, Hapus'),
              ),
            ],
          ),
    );
  }

  void _deleteAllToTrash() async {
    final now = DateTime.now();
    final formattedDate = DateFormat('dd-MM-yyyy').format(now);

    int updatedCount = 0;

    for (var order in _filteredOrders) {
      final isLead = order['lead'] == true;
      final key = order['key'];
      if (!isLead && key != null) {
        try {
          await _database.child(key).update({
            'status': 'trash',
            'statusUpdatedAt': formattedDate,
          });
          updatedCount++;
        } catch (e) {
          print("Gagal update order $key: $e");
        }
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Berhasil menghapus $updatedCount data')),
    );

    _fetchOrders();
  }

  void _showExportDatePickerDialog() async {
    final ref = FirebaseDatabase.instance.ref("orders");

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
        final tanggal = data['tanggal'];
        if (tanggal != null) {
          uniqueDates.add(tanggal);
        }
      }

      final sortedDates =
          uniqueDates.toList()..sort((a, b) {
            final dateA = DateTime.parse(_toIsoDate(a));
            final dateB = DateTime.parse(_toIsoDate(b));
            return dateB.compareTo(dateA);
          });

      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: Text("Pilih Tanggal untuk Export"),
              content: Container(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: sortedDates.length,
                  itemBuilder: (ctx, index) {
                    final date = sortedDates[index];
                    return ListTile(
                      title: Text(date),
                      onTap: () {
                        Navigator.pop(context);
                        _exportOrdersByDate(date);
                      },
                    );
                  },
                ),
              ),
            ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengambil tanggal: $e')));
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

  Future<void> _exportOrdersByDate(String selectedDate) async {
    setState(() => _isExporting = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator()),
    );

    final ref = FirebaseDatabase.instance.ref("orders");

    try {
      final snapshot =
          await ref.orderByChild("tanggal").equalTo(selectedDate).get();

      if (!snapshot.exists) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak ada data pada tanggal $selectedDate')),
        );
        return;
      }

      final List<Map> ordersToExport = [];

      for (final child in snapshot.children) {
        final data = Map<String, dynamic>.from(child.value as Map);
        data['key'] = child.key;
        ordersToExport.add(data);
      }

      if (ordersToExport.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak ada data pada tanggal $selectedDate')),
        );
        return;
      }

      final workbook = xlsio.Workbook();
      final sheet = workbook.worksheets[0];

      final headers = [
        'Tanggal Pengajuan',
        'Status',
        'Tanggal Perubahan Status',
        'Name',
        'Email',
        'Phone',
        'Job',
        'Income',
        'Item',
        'Merk',
        'Nominal',
        'Installment',
        'DP',
        'Domicile',
        'Postal Code',
        'Agent Name',
        'Agent Email',
        'Agent Phone',
        'Foto KTP',
        'Foto BPKB',
        'Foto KK',
        'Foto NPWP',
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

        sheet.getRangeByIndex(row, 1).rowHeight = 80;

        sheet.getRangeByIndex(row, 1).setText(order['tanggal'] ?? '');
        sheet.getRangeByIndex(row, 2).setText(order['status'] ?? '');
        sheet.getRangeByIndex(row, 3).setText(order['statusUpdatedAt'] ?? '');
        sheet.getRangeByIndex(row, 4).setText(order['name'] ?? '');
        sheet.getRangeByIndex(row, 5).setText(order['email'] ?? '');
        sheet.getRangeByIndex(row, 6).setText(order['phone'] ?? '');
        sheet.getRangeByIndex(row, 7).setText(order['job'] ?? '');
        sheet.getRangeByIndex(row, 8).setText(order['income'] ?? '');
        sheet.getRangeByIndex(row, 9).setText(order['item'] ?? '');
        sheet.getRangeByIndex(row, 10).setText(order['merk'] ?? '');
        sheet.getRangeByIndex(row, 11).setText(order['nominal'] ?? '');
        sheet.getRangeByIndex(row, 12).setText(order['installment'] ?? '');
        sheet.getRangeByIndex(row, 13).setText(order['dp'] ?? '');
        sheet.getRangeByIndex(row, 14).setText(order['domicile'] ?? '');
        sheet.getRangeByIndex(row, 15).setText(order['postalCode'] ?? '');
        sheet.getRangeByIndex(row, 16).setText(order['agentName'] ?? '');
        sheet.getRangeByIndex(row, 17).setText(order['agentEmail'] ?? '');
        sheet.getRangeByIndex(row, 18).setText(order['agentPhone'] ?? '');

        final ktpImageBytes = await _downloadImage(order['ktp']);
        final bpkbImageBytes = await _downloadImage(order['bpkb']);
        final kkImageBytes = await _downloadImage(order['kk']);
        final npwpImageBytes = await _downloadImage(order['npwp']);

        if (ktpImageBytes != null) {
          final picture = sheet.pictures.addBase64(
            row,
            19,
            base64Encode(ktpImageBytes),
          );
          picture.height = 80;
          picture.width = 120;
        }

        if (bpkbImageBytes != null) {
          final picture = sheet.pictures.addBase64(
            row,
            20,
            base64Encode(bpkbImageBytes),
          );
          picture.height = 80;
          picture.width = 120;
        }

        if (kkImageBytes != null) {
          final picture = sheet.pictures.addBase64(
            row,
            21,
            base64Encode(kkImageBytes),
          );
          picture.height = 80;
          picture.width = 120;
        }

        if (npwpImageBytes != null) {
          final picture = sheet.pictures.addBase64(
            row,
            22,
            base64Encode(npwpImageBytes),
          );
          picture.height = 80;
          picture.width = 120;
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

  Future<void> _addImageToCell(
    xlsio.Worksheet sheet,
    int row,
    int col,
    String? url,
  ) async {
    if (url == null || url.isEmpty) return;
    try {
      final response = await http.get(Uri.parse(url));
      final imageBytes = response.bodyBytes;
      sheet.pictures.addBase64(row, col, base64Encode(imageBytes));
    } catch (e) {
      print('Gagal ambil gambar: \$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F5),
      body: _buildMainPage(),
    );
  }
}
