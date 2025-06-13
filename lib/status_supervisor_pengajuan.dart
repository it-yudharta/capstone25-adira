import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'navbar_supervisor.dart';
import 'package:intl/intl.dart';
import 'order_detail_screen.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';

class StatusSupervisorPengajuan extends StatefulWidget {
  final String status;

  const StatusSupervisorPengajuan({Key? key, required this.status})
    : super(key: key);

  @override
  _StatusSupervisorPengajuanState createState() =>
      _StatusSupervisorPengajuanState();
}

class _StatusSupervisorPengajuanState extends State<StatusSupervisorPengajuan> {
  static const platform = MethodChannel('com.fundrain.adiraapp/download');
  List<Map<dynamic, dynamic>> _orders = [];
  List<Map<dynamic, dynamic>> _filteredOrders = [];
  Map<String, List<Map<dynamic, dynamic>>> groupedOrders = {};
  List<String> orderedDates = [];
  String _searchQuery = '';
  bool _isLoading = true;
  late TextEditingController _searchController;
  late FocusNode _focusNode;
  late String _currentStatus;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _focusNode = FocusNode();
    _currentStatus = widget.status;
    _fetchOrders();
  }

  void _fetchOrders() async {
    final dbRef = FirebaseDatabase.instance.ref().child('orders');

    if (_currentStatus == 'trash') {
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
      dbRef.orderByChild('status').equalTo(_currentStatus).onValue.listen((
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
      String date;

      if (_currentStatus == 'trash') {
        date = order['tanggal'] ?? 'Unknown';
      } else {
        final statusUpdatedAtKey = '${_currentStatus}UpdatedAt';
        date = order[statusUpdatedAtKey] ?? order['tanggal'] ?? 'Unknown';
      }

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
            } catch (e) {
              return DateTime(2000);
            }
          }

          return parseDate(b).compareTo(parseDate(a));
        });
  }

  void _logout() {
    Navigator.pop(context);
  }

  Map<String, List<Map<String, dynamic>>> _groupOrdersByDate(List orders) {
    Map<String, List<Map<String, dynamic>>> groupedData = {};
    for (var order in orders) {
      String date = order['created_at'] ?? 'Unknown Date';
      if (!groupedData.containsKey(date)) {
        groupedData[date] = [];
      }
      groupedData[date]!.add(Map<String, dynamic>.from(order));
    }
    return groupedData;
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

  void _changeStatus(String newStatus) {
    if (newStatus != _currentStatus) {
      setState(() {
        _currentStatus = newStatus;
        _isLoading = true;
      });
      _fetchOrders();
    }
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
                hintText: 'Search Data',
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
            crossAxisAlignment: CrossAxisAlignment.center,
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
                  _showExportByStatusUpdatedDatePickerDialogSupervisor(
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
              _isLoading
                  ? Center(child: CircularProgressIndicator())
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

  void _showExportByStatusUpdatedDatePickerDialogSupervisor(
    String status,
  ) async {
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
        final updatedAtKey = '${status}UpdatedAt';
        final statusUpdatedAt = data[updatedAtKey];
        final orderStatus = data['status'];
        if (statusUpdatedAt != null && orderStatus == status) {
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
        builder:
            (_) => AlertDialog(
              title: Text("Pilih Tanggal Perubahan Status"),
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
                        _exportOrdersByStatusUpdatedAtSupervisor(date, status);
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

  Future<void> _exportOrdersByStatusUpdatedAtSupervisor(
    String selectedDate,
    String status,
  ) async {
    setState(() => _isExporting = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator()),
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
          SnackBar(content: Text('Tidak ada data pada tanggal $selectedDate')),
        );
        return;
      }

      final List<Map> ordersToExport = [];

      for (final child in snapshot.children) {
        final data = Map<String, dynamic>.from(child.value as Map);
        if (data['status'] == status) {
          data['key'] = child.key;
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
        final dynamicOrder = ordersToExport[i];
        final order = Map<String, dynamic>.from(dynamicOrder);
        final row = i + 2;

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

        final ktpImageBytes = await _downloadImage(order['ktp']);
        final bpkbImageBytes = await _downloadImage(order['bpkb']);
        final kkImageBytes = await _downloadImage(order['kk']);
        final npwpImageBytes = await _downloadImage(order['npwp']);
        final slipgajiImageBytes = await _downloadImage(order['slipgaji']);
        final stnkImageBytes = await _downloadImage(order['stnk']);

        if (ktpImageBytes != null) {
          final picture = sheet.pictures.addBase64(
            row,
            23,
            base64Encode(ktpImageBytes),
          );
          picture.height = 80;
          picture.width = 120;
        }
        if (bpkbImageBytes != null) {
          final picture = sheet.pictures.addBase64(
            row,
            24,
            base64Encode(bpkbImageBytes),
          );
          picture.height = 80;
          picture.width = 120;
        }
        if (kkImageBytes != null) {
          final picture = sheet.pictures.addBase64(
            row,
            25,
            base64Encode(kkImageBytes),
          );
          picture.height = 80;
          picture.width = 120;
        }
        if (npwpImageBytes != null) {
          final picture = sheet.pictures.addBase64(
            row,
            26,
            base64Encode(npwpImageBytes),
          );
          picture.height = 80;
          picture.width = 120;
        }
        if (slipgajiImageBytes != null) {
          final picture = sheet.pictures.addBase64(
            row,
            27,
            base64Encode(slipgajiImageBytes),
          );
          picture.height = 80;
          picture.width = 120;
        }
        if (stnkImageBytes != null) {
          final picture = sheet.pictures.addBase64(
            row,
            28,
            base64Encode(stnkImageBytes),
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

  void _updateOrderStatus(String orderKey, String newStatus) async {
    final now = DateTime.now();
    final formattedDate = DateFormat('dd-MM-yyyy').format(now);

    Map<String, dynamic> updates = {
      'status': newStatus,
      '${newStatus}UpdatedAt': formattedDate,
    };

    try {
      final dbRef = FirebaseDatabase.instance
          .ref()
          .child('orders')
          .child(orderKey);
      await dbRef.update(updates);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status berhasil diperbarui ke $newStatus')),
      );
      _fetchOrders();
    } catch (e) {
      print("Gagal memperbarui status: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memperbarui status')));
    }
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
                  onTap: () async {},
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
                Text("Alamat      : ${order['domicile'] ?? '-'}"),
                SizedBox(height: 4),
                Text("Kode Pos  : ${order['postalCode'] ?? '-'}"),
                SizedBox(height: 4),
                Text(
                  "Status        : ${order['status'] ?? 'Belum diproses'}",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (order['note'] != null &&
                    order['note'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      "Note           : ${order['note']}",
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                SizedBox(height: 16),
                if (status == 'pending' && _currentStatus != 'trash')
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () => _updateOrderStatus(key, 'reject'),
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
                          onPressed: () => _updateOrderStatus(key, 'approve'),
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
}
