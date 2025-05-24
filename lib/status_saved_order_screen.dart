import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'order_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'custom_bottom_nav_bar.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/services.dart';

class StatusSavedOrderScreen extends StatefulWidget {
  final String status;
  final String title;

  const StatusSavedOrderScreen({
    Key? key,
    required this.status,
    required this.title,
  }) : super(key: key);

  @override
  _StatusSavedOrderScreenState createState() => _StatusSavedOrderScreenState();
}

class _StatusSavedOrderScreenState extends State<StatusSavedOrderScreen> {
  late String _currentStatus;
  late String _currentTitle;

  final DatabaseReference _database = FirebaseDatabase.instance.ref().child(
    'orders',
  );
  List<Map<dynamic, dynamic>> _filteredOrders = [];
  bool _isLoading = false;
  bool _isExporting = false;
  static const platform = MethodChannel('com.fundrain.adiraapp/download');
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.status;
    _currentTitle = widget.title;
    _fetchFilteredOrders();
  }

  void _logout() {
    Navigator.pop(context);
  }

  void _applySearch() {
    final query = _searchQuery.toLowerCase();
    setState(() {
      _filteredOrders =
          _filteredOrders.where((order) {
            final name = (order['name'] ?? '').toString().toLowerCase();
            final phone = (order['phone'] ?? '').toString().toLowerCase();
            return name.contains(query) || phone.contains(query);
          }).toList();
    });
  }

  Future<void> _fetchFilteredOrders() async {
    final snapshot = await _database.get();

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      final List<Map<dynamic, dynamic>> loaded = [];

      data.forEach((key, value) {
        final status = value['status'];
        final isTrash = value['trash'] == true;
        final isLead = value['lead'] == true;

        if (_currentStatus == 'trash') {
          if (isTrash && isLead) {
            value['key'] = key;
            loaded.add(value);
          }
        } else {
          if (!isTrash && isLead && status == _currentStatus) {
            value['key'] = key;
            loaded.add(value);
          }
        }
      });

      setState(() {
        _filteredOrders = loaded;
        groupedOrders = _groupOrdersByDate(_filteredOrders);
        _isLoading = false;
      });
    } else {
      setState(() {
        _filteredOrders = [];
        groupedOrders = {};
        _isLoading = false;
      });
    }
  }

  List<String> get orderedDates {
    final dates = groupedOrders.keys.toList();

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

  Map<String, List<Map<dynamic, dynamic>>> groupedOrders = {};

  Map<String, List<Map<dynamic, dynamic>>> _groupOrdersByDate(
    List<Map<dynamic, dynamic>> orders,
  ) {
    final Map<String, List<Map<dynamic, dynamic>>> grouped = {};
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

  Future<void> _launchWhatsApp(String phoneNumber) async {
    final Uri url = Uri.parse("https://wa.me/$phoneNumber");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  Future<void> _updateLeadStatus(String orderKey, bool isLead) async {
    await FirebaseDatabase.instance.ref('orders/$orderKey').update({
      'lead': isLead,
    });
  }

  void _confirmDeleteSingleToTrash(String key) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Hapus Data Ini?'),
            content: Text('Yakin ingin menghapus data ini ke Trash Bin?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Batal'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final now = DateTime.now();
                  final formattedDate = DateFormat('dd-MM-yyyy').format(now);
                  try {
                    await _database.child(key).update({
                      'trash': true,
                      'trashUpdatedAt': formattedDate,
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Data berhasil dipindahkan ke Trash'),
                      ),
                    );
                    _fetchFilteredOrders();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal menghapus data: $e')),
                    );
                  }
                },
                child: Text('Ya, Hapus'),
              ),
            ],
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
      {'label': 'Trash Bin', 'status': 'trash', 'icon': Icons.delete},
    ];

    return Container(
      margin: EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 5)],
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...List.generate(statusButtons.length * 2 - 1, (index) {
              if (index.isOdd) return SizedBox(width: 12);
              final item = statusButtons[index ~/ 2];
              final bool isActive = _currentStatus == item['status'];

              return InkWell(
                onTap: () async {
                  if (!isActive) {
                    setState(() {
                      _currentStatus = item['status'];
                      _currentTitle = item['label'];
                      _isLoading = true;
                    });
                    await _fetchFilteredOrders();
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
          ],
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
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFFF0F4F5),
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
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
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.black),
              onPressed: _logout,
            ),
          ],
        ),
      ),
      body: _buildMainPage(),
      bottomNavigationBar: const CustomBottomNavBar(currentRoute: 'other'),
    );
  }

  void _confirmDeleteAllLeadTrashPermanently() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Konfirmasi Hapus Permanen'),
            content: const Text(
              'Apakah Anda yakin ingin menghapus semua data Lead di Trash secara permanen? Tindakan ini tidak bisa dibatalkan.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  Navigator.pop(context);
                  _deleteAllLeadTrashPermanently();
                },
                child: const Text('Hapus Semua'),
              ),
            ],
          ),
    );
  }

  void _deleteAllLeadTrashPermanently() async {
    setState(() => _isLoading = true);

    final ref = FirebaseDatabase.instance.reference().child('orders');
    final snapshot = await ref.once();
    final data = snapshot.snapshot.value as Map<dynamic, dynamic>?;

    if (data != null) {
      for (var entry in data.entries) {
        final key = entry.key;
        final order = Map<String, dynamic>.from(entry.value);
        if (order['trash'] == true && order['lead'] == true) {
          await ref.child(key).remove();
        }
      }
    }

    setState(() => _isLoading = false);
    _fetchFilteredOrders();
  }

  Widget _buildMainPage() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: SizedBox(
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
                  borderSide: const BorderSide(
                    color: Color(0xFF0E5C36),
                    width: 1.5,
                  ),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: _buildStatusMenu(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_currentStatus == 'trash')
                ElevatedButton(
                  onPressed: _confirmDeleteAllLeadTrashPermanently,
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
                      Icon(Icons.delete_outline, size: 16, color: Colors.white),
                      SizedBox(height: 4),
                      Text(
                        'Delete All',
                        style: TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              if (_currentStatus != 'trash') ...[
                ElevatedButton(
                  onPressed: _confirmDeleteAllToTrash,
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
                      Icon(Icons.delete_outline, size: 16, color: Colors.white),
                      SizedBox(height: 4),
                      Text(
                        'Delete All',
                        style: TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    if (orderedDates.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Tidak ada data untuk diekspor'),
                        ),
                      );
                      return;
                    }
                    // Contoh: pilih tanggal via dialog sederhana
                    final selectedDate = await showDialog<String>(
                      context: context,
                      builder: (context) {
                        String tempDate = orderedDates.first;
                        return AlertDialog(
                          title: Text('Pilih tanggal export'),
                          content: DropdownButton<String>(
                            value: tempDate,
                            items:
                                orderedDates
                                    .map(
                                      (date) => DropdownMenuItem(
                                        value: date,
                                        child: Text(date),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (val) {
                              if (val != null) tempDate = val;
                            },
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, null),
                              child: Text('Batal'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, tempDate),
                              child: Text('OK'),
                            ),
                          ],
                        );
                      },
                    );

                    if (selectedDate != null) {
                      await _exportSavedOrdersByStatusAndLead(
                        selectedDate,
                        _currentStatus,
                      );
                    }
                  },
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
                    children: [
                      Image.asset(
                        'assets/icon/export_icon.png',
                        width: 16,
                        height: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Export by',
                        style: TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        SizedBox(height: 12),
        Expanded(
          child:
              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _filteredOrders.isEmpty
                  ? Center(
                    child: Text(
                      "Tidak ada order tersimpan dengan status '$_currentStatus'",
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
                          return _buildOrderCard(
                            order,
                            order['key'],
                            TextStyle(color: Colors.black87),
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

  Future<void> _exportSavedOrdersByStatusAndLead(
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
              'Tidak ada data "$status" dengan lead true di tanggal $selectedDate',
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
      final fileName = 'saved_order_${selectedDate}_$timestamp.xlsx';

      try {
        final savedPath = await platform.invokeMethod<String>(
          'saveFileToDownloads',
          {'fileName': fileName, 'bytes': bytes},
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
    } catch (e) {
      print('Error export: $e');
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengekspor: $e')));
    }
  }

  void _confirmDeleteAllToTrash() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Hapus Semua?'),
            content: Text('Yakin ingin menghapus semua data ke trash bin?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Batal'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _markAllStatusOrdersAsTrashed();
                },
                child: Text('Ya, Hapus'),
              ),
            ],
          ),
    );
  }

  void _markAllStatusOrdersAsTrashed() async {
    final now = DateTime.now();
    final formattedDate = DateFormat('dd-MM-yyyy').format(now);

    int trashedCount = 0;

    for (final order in _filteredOrders) {
      final key = order['key'];
      if (key != null) {
        try {
          await _database.child(key).update({
            'trash': true,
            'trashUpdatedAt': formattedDate,
          });
          trashedCount++;
        } catch (e) {
          debugPrint("Gagal menandai order $key sebagai trash: $e");
        }
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Berhasil menandai $trashedCount data sebagai trash'),
        ),
      );
      _fetchFilteredOrders();
    }
  }

  void _confirmDeleteSinglePermanently(String orderKey) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Konfirmasi Hapus Permanen'),
            content: const Text(
              'Apakah Anda yakin ingin menghapus data ini secara permanen? Tindakan ini tidak bisa dibatalkan.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  Navigator.pop(context);
                  await _deleteSingleTrashPermanently(orderKey);
                },
                child: const Text('Hapus Permanen'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteSingleTrashPermanently(String orderKey) async {
    setState(() => _isLoading = true);

    try {
      await FirebaseDatabase.instance
          .reference()
          .child('orders')
          .child(orderKey)
          .remove();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Data berhasil dihapus permanen')));

      _fetchFilteredOrders();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menghapus data: $e')));
    }

    setState(() => _isLoading = false);
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
                (context) =>
                    OrderDetailScreen(orderData: order, orderKey: order['key']),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
              child: Padding(
                padding: const EdgeInsets.only(right: 32.0),
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
                    Text("Pekerjaan    : ${order['job'] ?? '-'}"),
                    Text("Pengajuan    : ${order['installment'] ?? '-'}"),
                    SizedBox(height: 8),
                    Text(
                      "Status        : ${order['status'] ?? 'Belum diproses'}",
                    ),
                  ],
                ),
              ),
            ),
            if (isLead)
              Positioned(
                top: 12,
                left: 240,
                child: GestureDetector(
                  onTap: () async {
                    await _updateLeadStatus(orderKey, false);
                    await _fetchFilteredOrders();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Status lead dibatalkan')),
                    );
                  },
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
                  if (value == 'lead') {
                    setState(() => order['lead'] = true);
                    _updateLeadStatus(orderKey, true);
                    await _fetchFilteredOrders();
                  } else if (value == 'unlead') {
                    await _updateLeadStatus(orderKey, false);
                    await _fetchFilteredOrders();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Status lead dibatalkan')),
                    );
                  } else if (value == 'delete') {
                    _confirmDeleteSingleToTrash(orderKey);
                  } else if (value == 'delete_permanent') {
                    _confirmDeleteSinglePermanently(orderKey);
                  } else if (value == 'restore') {
                    try {
                      await FirebaseDatabase.instance
                          .reference()
                          .child('orders')
                          .child(orderKey)
                          .update({'trash': null, 'trashUpdatedAt': null});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Data berhasil di-restore')),
                      );
                      _fetchFilteredOrders();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal restore data: $e')),
                      );
                    }
                  }
                },
                itemBuilder: (BuildContext context) {
                  final isInTrash = _currentStatus == 'trash';
                  if (_currentStatus == 'trash') {
                    return [
                      PopupMenuItem<String>(
                        value: 'restore',
                        child: Text('Restore'),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete_permanent',
                        child: Text('Delete'),
                      ),
                    ];
                  } else {
                    return [
                      if (!isLead)
                        PopupMenuItem<String>(
                          value: 'lead',
                          child: Text('Mark as Lead'),
                        ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ];
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
