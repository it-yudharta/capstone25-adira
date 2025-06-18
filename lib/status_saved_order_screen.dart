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
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'circular_loading_indicator.dart';
import 'note_pengajuan.dart';

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
  void Function(VoidCallback fn)? _setExportDialogState;
  double _exportProgress = 0.0;

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
    setState(() => _isLoading = true);

    final snapshot = await _database.get();

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      final List<Map<dynamic, dynamic>> loaded = [];

      data.forEach((key, value) {
        final item = Map<String, dynamic>.from(value as Map);
        final status = item['status']?.toString().toLowerCase() ?? '';
        final isTrash = item['trash'] == true;
        final isLead = item['lead'] == true;

        bool matches = false;
        if (_currentStatus == 'trash') {
          matches = isTrash && isLead;
        } else {
          matches = !isTrash && isLead && status == _currentStatus;
        }

        if (matches) {
          // tambahkan key
          item['key'] = key;

          // ambil displayDate sesuai status
          String displayDate;
          if (_currentStatus == 'trash') {
            // sebelum trash, pakai statusUpdatedAt terakhir
            final updatedKey = '${status}UpdatedAt';
            displayDate = item[updatedKey] ?? item['tanggal'] ?? 'Unknown';
          } else {
            final updatedKey = '${_currentStatus}UpdatedAt';
            displayDate = item[updatedKey] ?? item['tanggal'] ?? 'Unknown';
          }
          item['displayDate'] = displayDate;

          loaded.add(item);
        }
      });

      setState(() {
        _filteredOrders = loaded;
        groupedOrders = _groupOrdersByDisplayDate(_filteredOrders);
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

  Map<String, List<Map<dynamic, dynamic>>> _groupOrdersByDisplayDate(
    List<Map<dynamic, dynamic>> orders,
  ) {
    final Map<String, List<Map<dynamic, dynamic>>> grouped = {};
    for (var order in orders) {
      final dateStr = order['displayDate']?.toString() ?? '';
      String dateKey;
      try {
        if (dateStr.isEmpty) throw FormatException();
        // format: 'dd-MM-yyyy' atau 'yyyy-MM-dd', sesuaikan DateFormat-nya jika perlu
        DateFormat('d-M-yyyy').parseStrict(dateStr);
        dateKey = dateStr;
      } catch (_) {
        dateKey = 'Tanggal tidak diketahui';
      }
      grouped.putIfAbsent(dateKey, () => []).add(order);
    }
    return grouped;
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

  void _changeStatus(String newStatus, String newTitle) {
    setState(() {
      _isLoading = true;
      _currentStatus = newStatus;
      _currentTitle = newTitle;
      _filteredOrders.clear();
      groupedOrders.clear();
    });
    _fetchFilteredOrders();
  }

  void _confirmDeleteSingleToTrash(String key) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
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
                  const Text(
                    'Delete Data Saved Pengajuan?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Data will first be moved to “Trash Bin”. From there,\n'
                    'you can recover them or permanently delete them.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFE67D13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Back',
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
                          onPressed: () async {
                            Navigator.pop(context);
                            final now = DateTime.now();
                            final formattedDate = DateFormat(
                              'dd-MM-yyyy',
                            ).format(now);
                            try {
                              await _database.child(key).update({
                                'trash': true,
                                'trashUpdatedAt': formattedDate,
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Data berhasil dipindahkan ke Trash',
                                  ),
                                ),
                              );
                              // refresh data saved pengajuan
                              await _fetchFilteredOrders();
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Gagal menghapus data: $e'),
                                ),
                              );
                            }
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFF0E5C36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Delete',
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
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 5)],
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(statusButtons.length * 2 - 1, (index) {
            if (index.isOdd) return const SizedBox(width: 31);
            final item = statusButtons[index ~/ 2];
            final bool isActive = _currentStatus == item['status'];

            return InkWell(
              onTap: () {
                if (!isActive) {
                  // ganti status layar ke yang dipilih
                  _changeStatus(item['status'], item['label']);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFF0E5C36) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(color: Colors.grey.shade300, blurRadius: 4),
                      ],
                    ),
                    child: _buildSvgIcon(item['icon'], isActive),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['label'],
                    style: TextStyle(
                      fontSize: 10,
                      color: isActive ? const Color(0xFF0E5C36) : Colors.black,
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
      case 'custom_cancel_icon':
        assetPath = 'assets/icon/cancel.svg';
        break;
      case 'custom_process_icon':
        assetPath = 'assets/icon/process.svg';
        break;
      case 'custom_pending_icon':
        assetPath = 'assets/icon/pending.svg';
        break;
      case 'custom_reject_icon':
        assetPath = 'assets/icon/reject.svg';
        break;
      case 'custom_approve_icon':
        assetPath = 'assets/icon/approve.svg';
        break;
      case 'custom_bin_icon':
        assetPath = 'assets/icon/bin.svg';
        break;
      default:
        return Icon(
          Icons.help_outline,
          size: 21,
          color: isActive ? Colors.white : const Color(0xFF0E5C36),
        );
    }

    return SvgPicture.asset(
      assetPath,
      width: 21,
      height: 21,
      color: isActive ? Colors.white : const Color(0xFF0E5C36),
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

  Widget _buildMainPage() {
    final baseStyle = Theme.of(context).textTheme.bodyMedium;

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
                  borderSide: const BorderSide(color: Colors.black, width: 1.2),
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
                            ? const Color(0xFF0E5C36)
                            : Colors.grey.shade600,
                  ),
                  onPressed:
                      () => FocusScope.of(context).requestFocus(_focusNode),
                ),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),

        const SizedBox(height: 8),

        _buildStatusMenu(),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Lead Pengajuan',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Row(
                children: [
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
                        Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: Colors.white,
                        ),
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
                    onPressed:
                        () => _showExportByStatusUpdatedDatePickerDialog(
                          _currentStatus,
                        ),
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
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        Expanded(
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredOrders.isEmpty
                  ? IgnorePointer(
                    ignoring: true,
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
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
                            const SizedBox(height: 8),
                            Text(
                              'No Data Found',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'No data lead pengajuan found',
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
                              style: const TextStyle(
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
                      return const SizedBox.shrink();
                    },
                  ),
        ),
      ],
    );
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

  Future<void> _showExportByStatusUpdatedDatePickerDialog(String status) async {
    final ref = FirebaseDatabase.instance.ref("orders");

    try {
      final snapshot = await ref.get();
      if (!snapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada data untuk diekspor')),
        );
        return;
      }

      final Set<String> uniqueDates = {};
      for (final child in snapshot.children) {
        final data = Map<String, dynamic>.from(child.value as Map);
        final updatedAtKey = '${status}UpdatedAt';
        if (data[updatedAtKey] != null &&
            data['status'] == status &&
            data['lead'] == true) {
          uniqueDates.add(data[updatedAtKey]);
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
          SnackBar(
            content: Text('Tidak ada data status "$status" dengan lead true'),
          ),
        );
        return;
      }

      String? _selectedExportDate;
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
                        "Pilih Tanggal Perubahan Status $status (lead)",
                        style: const TextStyle(
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
                      const SizedBox(height: 12),
                      if (showError)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Tanggal harus dipilih",
                              style: const TextStyle(
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
                                backgroundColor: const Color(0xFFE67D13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              child: const Text(
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
                              onPressed: () async {
                                if (_selectedExportDate != null) {
                                  await _exportSavedOrdersByStatusAndLead(
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
                                backgroundColor: const Color(0xFF0E5C36),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              child: const Text(
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

  Future<void> _exportSavedOrdersByStatusAndLead(
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
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
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
                  const Text(
                    'Delete All Data Saved Pengajuan?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Data will first be moved to “Trash Bin”. From there,\nyou can recover them or permanently delete them.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFE67D13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Back',
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
                            Navigator.pop(context);
                            _markAllStatusOrdersAsTrashed();
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFF0E5C36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Delete All',
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

  void _showCancelConfirmationSaved(String orderKey) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
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
                  const Text(
                    'Cancel Pengajuan?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Pengajuan will be canceled and\nmoved to “Cancel”.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFE67D13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Back',
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
                            Navigator.pop(context);
                            // Panggil fungsi cancel-mu—misal:
                            updateStatus(orderKey, 'cancel');
                            // lalu muat ulang data:
                            _fetchFilteredOrders();
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFF0E5C36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
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

  void updateStatus(String key, String newStatus) async {
    final now = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final dbRef = FirebaseDatabase.instance.ref().child('orders/$key');

    String updatedFieldName = '${newStatus}UpdatedAt';

    await dbRef.update({'status': newStatus, updatedFieldName: now});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Status berhasil diubah menjadi $newStatus')),
    );
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
                    OrderDetailScreen(orderData: order, orderKey: orderKey),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(left: 10, right: 10, top: 4, bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            DefaultTextStyle.merge(
              style: baseStyle!,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Agent         : ${order['agentName'] ?? '-'}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text("Nama         : ${order['name'] ?? '-'}"),
                  Text("Alamat       : ${order['domicile'] ?? '-'}"),
                  const SizedBox(height: 4),

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
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        children: [
                          const TextSpan(text: "No. Telp      : "),
                          TextSpan(
                            text: phoneNumber,
                            style: const TextStyle(color: Colors.blue),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text("Pekerjaan  : ${order['job'] ?? '-'}"),
                  Text("Pengajuan : ${order['installment'] ?? '-'}"),
                  const SizedBox(height: 8),
                  if (!(isLead && order['status'] == 'lead'))
                    Text(
                      "Status        : ${order['status'] ?? 'Belum diproses'}",
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

                  if (_currentStatus == 'process')
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            onPressed:
                                () => _showCancelConfirmationSaved(orderKey),
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
                                SvgPicture.asset(
                                  'assets/icon/button_cancel.svg',
                                  width: 16,
                                  height: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Cancel',
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
                            onPressed: () {
                              Navigator.push<String?>(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => NotePengajuanScreen(
                                        orderData: order,
                                        orderKey: orderKey,
                                      ),
                                ),
                              ).then((newNote) {
                                if (newNote != null && newNote.isNotEmpty) {
                                  setState(() {
                                    order['note'] = newNote;
                                    order['status'] = 'pending';
                                    order['pendingUpdatedAt'] = DateFormat(
                                      'dd-MM-yyyy',
                                    ).format(DateTime.now());
                                    _applySearch();
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Catatan disimpan'),
                                    ),
                                  );
                                }
                              });
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
                                SvgPicture.asset(
                                  'assets/icon/add_note.svg',
                                  width: 16,
                                  height: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Add Note',
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
                  padding: const EdgeInsets.only(top: 8, right: 36),
                  child: GestureDetector(
                    onTap: () async {
                      setState(() => order['lead'] = false);
                      await _updateLeadStatus(orderKey, false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Status lead dibatalkan')),
                      );
                    },
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
              ),

            Positioned(
              top: 0,
              right: 0,
              child: PopupMenuButton<String>(
                color: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onSelected: (value) async {
                  if (value == 'lead') {
                    setState(() => order['lead'] = true);
                    await _updateLeadStatus(orderKey, true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Status lead ditandai')),
                    );
                  } else if (value == 'delete') {
                    _confirmDeleteSingleToTrash(orderKey);
                  } else if (value == 'restore') {
                    await _database.child(orderKey).update({
                      'trash': null,
                      'trashUpdatedAt': null,
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Data berhasil di-restore')),
                    );
                    _fetchFilteredOrders();
                  } else if (value == 'delete_permanent') {
                    _confirmDeleteSinglePermanently(orderKey);
                  }
                },
                itemBuilder: (context) {
                  if (_currentStatus == 'trash') {
                    return [
                      PopupMenuItem<String>(
                        value: 'restore',
                        child: Row(
                          children: const [
                            Icon(Icons.restore, color: Color(0xFF0E5C36)),
                            SizedBox(width: 10),
                            Text(
                              'Restore',
                              style: TextStyle(color: Color(0xFF0E5C36)),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem<String>(
                        value: 'delete_permanent',
                        child: Row(
                          children: const [
                            Icon(Icons.delete, color: Color(0xFF0E5C36)),
                            SizedBox(width: 10),
                            Text(
                              'Delete',
                              style: TextStyle(color: Color(0xFF0E5C36)),
                            ),
                          ],
                        ),
                      ),
                    ];
                  } else {
                    List<PopupMenuEntry<String>> items = [];
                    if (!isLead) {
                      items.add(
                        PopupMenuItem<String>(
                          value: 'lead',
                          child: Row(
                            children: const [
                              Icon(Icons.bookmark, color: Color(0xFF0E5C36)),
                              SizedBox(width: 10),
                              Text(
                                'Lead',
                                style: TextStyle(color: Color(0xFF0E5C36)),
                              ),
                            ],
                          ),
                        ),
                      );
                      items.add(const PopupMenuDivider());
                    }
                    items.add(
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: const [
                            Icon(Icons.delete, color: Color(0xFF0E5C36)),
                            SizedBox(width: 10),
                            Text(
                              'Delete',
                              style: TextStyle(color: Color(0xFF0E5C36)),
                            ),
                          ],
                        ),
                      ),
                    );
                    return items;
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
