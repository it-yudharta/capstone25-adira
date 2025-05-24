import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'order_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'custom_bottom_nav_bar.dart';
import 'package:intl/intl.dart';

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
                  onPressed: () {},
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
