import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'bottom_nav_bar_pendaftaran.dart';
import 'package:url_launcher/url_launcher.dart';
import 'pendaftaran_detail_screen.dart';

class StatusSavedPendaftaranScreen extends StatefulWidget {
  const StatusSavedPendaftaranScreen({required this.status});

  final String status;

  @override
  State<StatusSavedPendaftaranScreen> createState() =>
      _StatusSavedPendaftaranScreenState();
}

class _StatusSavedPendaftaranScreenState
    extends State<StatusSavedPendaftaranScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = '';

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child(
    'agent-form',
  );

  List<Map<dynamic, dynamic>> _pendaftarans = [];
  Map<String, List<Map>> groupedPendaftarans = {};
  List<String> orderedDates = [];
  late String currentStatus;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    currentStatus = widget.status;
    _fetchData();
  }

  void _fetchData() {
    setState(() => _isLoading = true);

    _dbRef.orderByChild('status').equalTo(currentStatus).once().then((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        final List<Map<dynamic, dynamic>> items = [];
        data.forEach((key, value) {
          final item = Map<dynamic, dynamic>.from(value);
          final bool isLead = item['lead'] == true;
          final bool isTrash = item['trash'] == true || item['trash'] == 'true';

          if (isLead && !isTrash) {
            item['key'] = key;
            items.add(item);
          }
        });

        setState(() {
          _pendaftarans = items;
          _groupByDate();
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

  void _applySearch() {
    setState(() {
      groupedPendaftarans.clear();

      for (var item in _filteredPendaftarans) {
        final dateField = '${currentStatus.toLowerCase()}UpdatedAt';
        final date = formatTanggal(item[dateField]);

        if (!groupedPendaftarans.containsKey(date)) {
          groupedPendaftarans[date] = [];
        }
        groupedPendaftarans[date]!.add(item);
      }

      orderedDates =
          groupedPendaftarans.keys.toList()..sort((a, b) {
            DateTime parseDate(String d) {
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

            return parseDate(b).compareTo(parseDate(a));
          });
    });
  }

  void _groupByDate() {
    groupedPendaftarans.clear();

    for (var item in _pendaftarans) {
      final dateField = '${currentStatus.toLowerCase()}UpdatedAt';
      final date = formatTanggal(item[dateField]);

      if (!groupedPendaftarans.containsKey(date)) {
        groupedPendaftarans[date] = [];
      }
      groupedPendaftarans[date]!.add(item);
    }

    orderedDates =
        groupedPendaftarans.keys.toList()..sort((a, b) {
          DateTime parseDate(String d) {
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

          return parseDate(b).compareTo(parseDate(a));
        });
  }

  List<Map> get _filteredPendaftarans {
    if (_searchQuery.isEmpty) {
      return _pendaftarans;
    }

    return _pendaftarans.where((item) {
      final query = _searchQuery.toLowerCase();
      return (item['fullName']?.toString().toLowerCase().contains(query) ??
              false) ||
          (item['email']?.toString().toLowerCase().contains(query) ?? false) ||
          (item['phone']?.toString().toLowerCase().contains(query) ?? false);
    }).toList();
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

  void _logout() {
    Navigator.pop(context);
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

  void _showCancelConfirmation(String key) {
    // Implementasi konfirmasi cancel
  }

  Future<void> _toggleBookmarkStatus(String key, bool newStatus) async {
    // Implementasi toggle bookmark
  }

  Future<void> _updateLeadStatusPendaftaran(String key, bool isLead) async {
    // Implementasi update status lead
  }

  void _confirmDeleteSingleToTrashPendaftaran(String key) {
    // Implementasi delete ke trash
  }

  void exportData(Map data) {
    // Implementasi export data
  }

  Widget _buildSavedPendaftaranCard(
    Map data,
    String key,
    TextStyle? baseStyle,
  ) {
    final phone = data['phone'] ?? '-';
    final bool isBookmarked = data['isBookmarked'] == true;
    final status = data['status'] ?? '-';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PendaftaranDetailScreen(agentData: data),
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
              style: baseStyle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Nama        : ${data['fullName'] ?? '-'}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text("Email         : ${data['email'] ?? '-'}"),
                  const SizedBox(height: 4),
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
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        children: [
                          const TextSpan(text: "No. Telp     : "),
                          TextSpan(
                            text: phone,
                            style: const TextStyle(color: Colors.blue),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text("Alamat      : ${data['address'] ?? '-'}"),
                  const SizedBox(height: 4),
                  Text("Kode Pos  : ${data['postalCode'] ?? '-'}"),
                  const SizedBox(height: 4),
                  Text("Status       : $status"),
                  const SizedBox(height: 16),

                  if (status.toLowerCase() == 'process' &&
                      widget.status != 'trash')
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () => _showCancelConfirmation(key),
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

            Positioned(
              top: 0,
              right: 36,
              child: GestureDetector(
                onTap: () async {
                  await _toggleBookmarkStatus(key, !isBookmarked);
                  setState(() {});
                },
                child: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  size: 24,
                  color: const Color(0xFF0E5C36),
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
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Status lead ditandai')),
                    );
                  } else if (value == 'delete') {
                    _confirmDeleteSingleToTrashPendaftaran(key);
                  } else if (value == 'export') {
                    exportData(data);
                  }
                },
                itemBuilder: (BuildContext context) {
                  return [
                    PopupMenuItem<String>(
                      value: 'export',
                      child: Text('Export'),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Delete'),
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
            final bool isActive = currentStatus == item['status'];

            return InkWell(
              onTap: () {
                if (!isActive) {
                  setState(() {
                    currentStatus = item['status'];
                    _fetchData();
                  });
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
                'Lead Pendaftaran',
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
                      onPressed: () {},
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
                      onPressed: () {},
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
                  ? Center(child: Text("Tidak ada data saved pendaftaran"))
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
                          final key = item['key'] ?? '';
                          return _buildSavedPendaftaranCard(
                            item,
                            key,
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
      body: Column(children: [Expanded(child: _buildMainPage())]),
      bottomNavigationBar: BottomNavBarPendaftaran(
        currentRoute: 'status_saved',
      ),
    );
  }
}
