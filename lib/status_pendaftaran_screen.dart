import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'bottom_nav_bar_pendaftaran.dart';
import 'package:url_launcher/url_launcher.dart';
import 'pendaftaran_detail_screen.dart';
import 'dart:async';

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
  final DatabaseReference _database = FirebaseDatabase.instance.ref().child(
    'agent-form',
  );

  StreamSubscription<DatabaseEvent>? _dataSubscription;

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

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _fetchPendaftarans() {
    _dataSubscription
        ?.cancel(); // batalkan listener lama sebelum buat listener baru

    final dbRef = FirebaseDatabase.instance.ref().child('agent-form');
    setState(() => _isLoading = true);

    if (widget.status == 'trash') {
      _dataSubscription = dbRef.onValue.listen((event) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;

        if (data != null) {
          final List<Map<dynamic, dynamic>> items = [];
          data.forEach((key, value) {
            final Map<dynamic, dynamic> item = Map<dynamic, dynamic>.from(
              value,
            );
            if (item['trash'] == true || item['trash'] == 'true') {
              item['key'] = key;
              items.add(item);
            }
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
    } else {
      _dataSubscription = dbRef
          .orderByChild('status')
          .equalTo(widget.status)
          .onValue
          .listen((event) {
            final data = event.snapshot.value as Map<dynamic, dynamic>?;

            if (data != null) {
              final List<Map<dynamic, dynamic>> items = [];
              data.forEach((key, value) {
                final Map<dynamic, dynamic> item = Map<dynamic, dynamic>.from(
                  value,
                );
                if (item['trash'] != true && item['trash'] != 'true') {
                  item['key'] = key;
                  items.add(item);
                }
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
  }

  void _applySearch() {
    final query = _searchQuery.toLowerCase();

    _filteredPendaftarans =
        _pendaftarans.where((item) {
          final name = (item['fullName'] ?? '').toString().toLowerCase();
          final status = (item['status'] ?? '').toString().toLowerCase();
          final isTrash = item['trash'] == true || item['trash'] == 'true';
          if (widget.status == 'trash') {
            return isTrash && name.contains(query);
          }

          return !isTrash &&
              status == widget.status.toLowerCase() &&
              name.contains(query);
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
        final parsedDate = DateFormat('dd-MM-yyyy').parse(tanggal);
        return DateFormat('dd-MM-yyyy').format(parsedDate);
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

  void _showCancelConfirmation(String agentKey) {
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
                    'Cancel Pendaftaran?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Pendaftaran will be canceled and\nmoved to “Cancel”.',
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
                            _updateAgentStatus(agentKey, 'cancel');
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

  void _updateAgentStatus(String agentKey, String newStatus) async {
    final now = DateTime.now();
    final formattedDate = DateFormat('dd-MM-yyyy').format(now);

    Map<String, dynamic> updates = {
      'status': newStatus,
      '${newStatus}UpdatedAt': formattedDate,
    };

    try {
      await _database.child(agentKey).update(updates);
      _fetchPendaftarans();
    } catch (e) {
      print("Gagal memperbarui status: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memperbarui status')));
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

  Future<void> _updateLeadStatusPendaftaran(
    String agentKey,
    bool isLead,
  ) async {
    final agentRef = FirebaseDatabase.instance
        .ref()
        .child('agent-form')
        .child(agentKey);
    try {
      await agentRef.update({'lead': isLead});
    } catch (error) {
      print("Gagal mengubah status lead: $error");
    }
  }

  void _confirmDeleteSingleToTrashPendaftaran(String key) {
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
                    await FirebaseDatabase.instance
                        .ref()
                        .child('agent-form')
                        .child(key)
                        .update({
                          'trash': true,
                          'trashUpdatedAt': formattedDate,
                        });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Data berhasil dipindahkan ke Trash'),
                      ),
                    );
                    _fetchPendaftarans();
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

  Widget _buildPendaftaranCard(
    Map pendaftaran,
    String key,
    TextStyle? baseStyle,
  ) {
    final phone = pendaftaran['phone'] ?? '-';
    final bool isLead = pendaftaran['lead'] == true;
    final status = pendaftaran['status'] ?? 'Belum diproses';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => PendaftaranDetailScreen(agentData: pendaftaran),
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
            DefaultTextStyle.merge(
              style: baseStyle,
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
                    onTap: () async {
                      try {
                        await _launchWhatsApp(phone);
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
                  Text("Alamat      : ${pendaftaran['address'] ?? '-'}"),
                  SizedBox(height: 4),
                  Text("Kode Pos  : ${pendaftaran['postalCode'] ?? '-'}"),
                  SizedBox(height: 4),
                  if (!(isLead && status == 'lead'))
                    Text("Status       : $status"),
                  SizedBox(height: 16),

                  if ((status.toLowerCase() == 'process') &&
                      widget.status != 'trash')
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () => _showCancelConfirmation(key),
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
                    ),
                ],
              ),
            ),

            if (isLead)
              Positioned(
                top: 12,
                left: 280,
                child: GestureDetector(
                  onTap: () async {
                    await _updateLeadStatusPendaftaran(key, false);

                    setState(() {
                      final index = _pendaftarans.indexWhere(
                        (item) => item['key'] == key,
                      );
                      if (index != -1) {
                        _pendaftarans[index]['lead'] = false;
                        _applySearch();
                      }
                    });

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
                    await _updateLeadStatusPendaftaran(key, true);

                    setState(() {
                      final index = _pendaftarans.indexWhere(
                        (item) => item['key'] == key,
                      );
                      if (index != -1) {
                        _pendaftarans[index]['lead'] = true;
                        _applySearch();
                      }
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Status lead ditandai')),
                    );
                  } else if (value == 'delete') {
                    _confirmDeleteSingleToTrashPendaftaran(key);
                  }
                },
                itemBuilder: (BuildContext context) {
                  return [
                    if (!isLead)
                      PopupMenuItem<String>(value: 'lead', child: Text('Lead')),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ];
                },
              ),
            ),

            if (widget.status == 'trash')
              Positioned(
                top: 0,
                right: 0,
                child: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'restore') {
                      try {
                        await FirebaseDatabase.instance
                            .ref()
                            .child('agent-form')
                            .child(key)
                            .update({'trash': null, 'trashUpdatedAt': null});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Data berhasil di-restore')),
                        );
                        _fetchPendaftarans();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Gagal restore data: $e')),
                        );
                      }
                    } else if (value == 'delete_permanent') {
                      _confirmDeleteSinglePermanently(key);
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    return [
                      PopupMenuItem<String>(
                        value: 'restore',
                        child: Text('Restore'),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete_permanent',
                        child: Text('Delete Permanen'),
                      ),
                    ];
                  },
                ),
              ),
          ],
        ),
      ),
    );
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
          .ref()
          .child('agent-form')
          .child(orderKey)
          .remove();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Data berhasil dihapus permanen')));

      _fetchPendaftarans();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menghapus data: $e')));
    }

    setState(() => _isLoading = false);
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

              if (widget.status != 'trash')
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _confirmDeleteAllRegistrationsToTrashStatus,
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
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Tambahkan logika export by date
                      },
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
            ],
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

  void _confirmDeleteAllRegistrationsToTrashStatus() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Hapus Semua?'),
            content: Text(
              'Yakin ingin menghapus semua data pendaftaran (non-lead)?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Batal'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _markAllRegistrationsAsTrashedStatus();
                },
                child: Text('Ya, Hapus'),
              ),
            ],
          ),
    );
  }

  void _markAllRegistrationsAsTrashedStatus() async {
    final now = DateTime.now();
    final formattedDate = DateFormat('dd-MM-yyyy').format(now);

    int trashedCount = 0;

    for (final item in _filteredPendaftarans) {
      final isLead = item['lead'] == true;
      final key = item['key'];

      if (!isLead && key != null) {
        try {
          await _database.child(key).update({
            'trash': true,
            'trashUpdatedAt': formattedDate,
          });
          trashedCount++;
        } catch (e) {
          debugPrint("Gagal menandai pendaftaran $key sebagai trash: $e");
        }
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Berhasil menandai $trashedCount data sebagai trash'),
        ),
      );
      _fetchPendaftarans();
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
      bottomNavigationBar: BottomNavBarPendaftaran(currentRoute: 'status'),
    );
  }
}
