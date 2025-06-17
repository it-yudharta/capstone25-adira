import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'bottom_nav_bar_pendaftaran.dart';
import 'package:url_launcher/url_launcher.dart';
import 'pendaftaran_detail_screen.dart';
import 'dart:convert';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
  static const platform = MethodChannel('com.fundrain.adiraapp/download');
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
  bool _isExporting = false;

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

  void _confirmDeleteSingleToTrashPendaftaran(String key) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Hapus Data Ini?'),
            content: const Text('Yakin ingin menghapus data ini ke Trash Bin?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final now = DateTime.now();
                  final formattedDate = DateFormat('dd-MM-yyyy').format(now);
                  try {
                    await FirebaseDatabase.instance
                        .ref('agent-form/$key')
                        .update({
                          'trash': true,
                          'trashUpdatedAt': formattedDate,
                        });

                    setState(() {
                      for (var date in orderedDates) {
                        groupedPendaftarans[date]?.removeWhere(
                          (item) => item['key'] == key,
                        );
                      }
                      orderedDates.removeWhere(
                        (date) =>
                            groupedPendaftarans[date] == null ||
                            groupedPendaftarans[date]!.isEmpty,
                      );
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Data berhasil dipindahkan ke Trash'),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal menghapus data: $e')),
                    );
                  }
                },
                child: const Text('Ya, Hapus'),
              ),
            ],
          ),
    );
  }

  Widget _buildSavedPendaftaranCard(
    Map data,
    String key,
    TextStyle? baseStyle,
  ) {
    final phone = data['phone'] ?? '-';
    final status = data['status'] ?? '-';
    final bool isLead = data['lead'] == true;

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
              right: 0,
              child: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'lead') {
                    (key, true);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Status lead ditandai')),
                    );
                  } else if (value == 'delete') {
                    _confirmDeleteSingleToTrashPendaftaran(key);
                  }
                },
                itemBuilder: (BuildContext context) {
                  return [
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ];
                },
              ),
            ),

            if (isLead)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 36),
                  child: GestureDetector(
                    onTap: () async {
                      await FirebaseDatabase.instance
                          .ref('agent-form/$key')
                          .update({'lead': false});
                      setState(() {
                        for (var date in orderedDates) {
                          groupedPendaftarans[date]?.removeWhere(
                            (item) => item['key'] == key,
                          );
                        }
                        orderedDates.removeWhere(
                          (date) =>
                              groupedPendaftarans[date] == null ||
                              groupedPendaftarans[date]!.isEmpty,
                        );
                      });

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
          ],
        ),
      ),
    );
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
                          onPressed: () async {
                            Navigator.pop(context);
                            final now = DateTime.now();
                            final formattedDate = DateFormat(
                              'dd-MM-yyyy',
                            ).format(now);
                            await FirebaseDatabase.instance
                                .ref('agent-form/$agentKey')
                                .update({
                                  'status': 'cancel',
                                  'updatedAt': formattedDate,
                                });

                            setState(() {
                              for (var date in orderedDates) {
                                groupedPendaftarans[date]?.removeWhere(
                                  (item) => item['key'] == agentKey,
                                );
                              }
                              orderedDates.removeWhere(
                                (date) =>
                                    groupedPendaftarans[date] == null ||
                                    groupedPendaftarans[date]!.isEmpty,
                              );
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Pendaftaran dibatalkan'),
                              ),
                            );
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

  void _confirmDeleteAllLeadToTrash() {
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
                  _markAllStatusPendaftaranAsTrashed();
                },
                child: Text('Ya, Hapus'),
              ),
            ],
          ),
    );
  }

  void _markAllStatusPendaftaranAsTrashed() async {
    final now = DateTime.now();
    final formattedDate = DateFormat('dd-MM-yyyy').format(now);

    int trashedCount = 0;

    for (final data in _filteredPendaftarans) {
      final key = data['key'];
      if (key != null) {
        try {
          await _dbRef.child(key).update({
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
      _fetchData();
    }
  }

  void _showExportSavedPendaftaranByStatusUpdatedDatePickerDialog(
    String status,
  ) async {
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
        final orderStatus = data['status'];
        final bool isLead = data['lead'] == true;
        final bool isTrash = data['trash'] == true || data['trash'] == 'true';

        if (statusUpdatedAt != null &&
            orderStatus == status &&
            isLead &&
            !isTrash) {
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
                        _exportSavedPendaftaranByStatusUpdatedAt(date, status);
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

  Future<void> _exportSavedPendaftaranByStatusUpdatedAt(
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

      if (!snapshot.exists) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak ada data pada tanggal $selectedDate')),
        );
        return;
      }

      final List<Map> pendaftaransToExport = [];

      for (final child in snapshot.children) {
        final data = Map<String, dynamic>.from(child.value as Map);
        final bool isLead = data['lead'] == true;
        final bool isTrash = data['trash'] == true || data['trash'] == 'true';

        if (data['status'] == status && isLead && !isTrash) {
          data['key'] = child.key;
          pendaftaransToExport.add(data);
        }
      }

      if (pendaftaransToExport.isEmpty) {
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

      for (int col = 19; col <= 22; col++) {
        sheet.getRangeByIndex(1, col).columnWidth = 20;
      }

      for (int i = 0; i < pendaftaransToExport.length; i++) {
        final item = pendaftaransToExport[i];
        final row = i + 2;

        sheet.getRangeByIndex(row, 1).rowHeight = 80;

        sheet.getRangeByIndex(row, 1).setText(item['tanggal'] ?? '');
        sheet.getRangeByIndex(row, 2).setText(item['status'] ?? '');
        sheet.getRangeByIndex(row, 3).setText(item['cancelUpdatedAt'] ?? '');
        sheet.getRangeByIndex(row, 4).setText(item['processUpdatedAt'] ?? '');
        sheet.getRangeByIndex(row, 5).setText(item['pendingUpdatedAt'] ?? '');
        sheet.getRangeByIndex(row, 6).setText(item['rejectUpdatedAt'] ?? '');
        sheet.getRangeByIndex(row, 7).setText(item['approveUpdatedAt'] ?? '');
        sheet.getRangeByIndex(row, 8).setText(item['qr_givenUpdatedAt'] ?? '');
        sheet.getRangeByIndex(row, 9).setText(item['name'] ?? '');
        sheet.getRangeByIndex(row, 10).setText(item['email'] ?? '');
        sheet.getRangeByIndex(row, 11).setText(item['phone'] ?? '');
        sheet.getRangeByIndex(row, 12).setText(item['address'] ?? '');
        sheet.getRangeByIndex(row, 13).setText(item['postalCode'] ?? '');

        final kkImageBytes = await _downloadImage(item['kk']);
        final ktpImageBytes = await _downloadImage(item['ktp']);
        final npwpImageBytes = await _downloadImage(item['npwp']);

        if (kkImageBytes != null) {
          final picture = sheet.pictures.addBase64(
            row,
            14,
            base64Encode(kkImageBytes),
          );
          picture.height = 80;
          picture.width = 120;
        }
        if (ktpImageBytes != null) {
          final picture = sheet.pictures.addBase64(
            row,
            15,
            base64Encode(ktpImageBytes),
          );
          picture.height = 80;
          picture.width = 120;
        }
        if (npwpImageBytes != null) {
          final picture = sheet.pictures.addBase64(
            row,
            16,
            base64Encode(npwpImageBytes),
          );
          picture.height = 80;
          picture.width = 120;
        }
      }

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      try {
        final savedPath = await platform
            .invokeMethod<String>('saveFileToDownloads', {
              'fileName': 'saved_pendaftaran_${selectedDate}_$timestamp.xlsx',
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
    } catch (e) {
      print('Error export: $e');
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

              Row(
                children: [
                  ElevatedButton(
                    onPressed: _confirmDeleteAllLeadToTrash,
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
                      _showExportSavedPendaftaranByStatusUpdatedDatePickerDialog(
                        currentStatus,
                      );
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
                  : (orderedDates.isEmpty || groupedPendaftarans.isEmpty)
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
