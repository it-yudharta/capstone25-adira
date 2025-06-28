// ignore_for_file: must_be_immutable, unused_field, unnecessary_import, use_super_parameters, library_private_types_in_public_api, use_build_context_synchronously, avoid_print, deprecated_member_use, sized_box_for_whitespace

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'bottom_nav_bar_pendaftaran.dart';
import 'package:url_launcher/url_launcher.dart';
import 'pendaftaran_detail_screen.dart';
import 'dart:async';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'generate_qr_pengajuan.dart';
import 'circular_loading_indicator.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'note_pendaftaran.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';

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
  static const platform = MethodChannel('com.fundrain.adiraapp/download');
  bool _isExporting = false;
  List<Map<dynamic, dynamic>> _pendaftarans = [];
  List<Map<dynamic, dynamic>> _filteredPendaftarans = [];
  Map<String, List<Map<dynamic, dynamic>>> groupedPendaftarans = {};
  List<String> orderedDates = [];
  String _searchQuery = '';
  String? _selectedExportDate;
  late void Function(void Function()) _setExportDialogState;
  double _exportProgress = 0.0;

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
    _dataSubscription?.cancel();

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
          final phone = (item['phone'] ?? '').toString().toLowerCase();
          final status = (item['status'] ?? '').toString().toLowerCase();
          final statusField = '${widget.status.toLowerCase()}UpdatedAt';
          final date = formatTanggal(item[statusField]).toLowerCase();

          final isTrash = item['trash'] == true || item['trash'] == 'true';

          final isMatch =
              name.contains(query) ||
              phone.contains(query) ||
              date.contains(query);

          if (widget.status == 'trash') {
            return isTrash && isMatch;
          }

          return !isTrash && status == widget.status.toLowerCase() && isMatch;
        }).toList();

    groupedPendaftarans.clear();

    for (var item in _filteredPendaftarans) {
      String statusField = '${widget.status.toLowerCase()}UpdatedAt';
      final date = formatTanggal(item[statusField]);
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

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
      (route) => false,
    );
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
    final now = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final dbRef = FirebaseDatabase.instance.ref().child(
      'pendaftaran/$agentKey',
    );

    String updatedFieldName = '${newStatus}UpdatedAt';

    try {
      await dbRef.update({'status': newStatus, updatedFieldName: now});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status berhasil diubah menjadi $newStatus')),
      );

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
      {'label': 'Cancel', 'status': 'cancel', 'icon': 'custom_cancel_icon'},
      {'label': 'Process', 'status': 'process', 'icon': 'custom_process_icon'},
      {'label': 'Pending', 'status': 'pending', 'icon': 'custom_pending_icon'},
      {'label': 'Reject', 'status': 'reject', 'icon': 'custom_reject_icon'},
      {'label': 'Approve', 'status': 'approve', 'icon': 'custom_approve_icon'},
      {'label': 'QR Given', 'status': 'qr_given', 'icon': 'custom_qr_icon'},
      {'label': 'Trash Bin', 'status': 'trash', 'icon': 'custom_bin_icon'},
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
            final bool isActive = widget.status == item['status'];

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
                    'Delete Data Pendaftaran?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Data will first be moved to “Trash Bin”. From there,\nyou can recover them or permanently delete them.',
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
                                  content: Text(
                                    'Data berhasil dipindahkan ke Trash',
                                  ),
                                ),
                              );
                              _fetchPendaftarans();
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Gagal menghapus data: $e'),
                                ),
                              );
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
                    Text(
                      "Status       : $status",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  if (pendaftaran['note'] != null &&
                      pendaftaran['note'].toString().isNotEmpty)
                    Text(
                      "Note          : ${pendaftaran['note']}",
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  SizedBox(height: 16),
                  if (status == 'approve' && widget.status != 'trash')
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => GenerateQRPengajuan(
                                    fullName: pendaftaran['fullName'] ?? '',
                                    email: pendaftaran['email'] ?? '',
                                    phone: pendaftaran['phone'] ?? '',
                                    pendaftaranKey: key,
                                  ),
                            ),
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
                        child: Text(
                          'Generate QR',
                          style: TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      ),
                    ),

                  if (status == 'process' && widget.status != 'trash')
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
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
                                Icon(
                                  Icons.cancel,
                                  size: 16,
                                  color: Colors.white,
                                ),
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
                            onPressed: () {
                              Navigator.push<String?>(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => NotePendaftaranScreen(
                                        pendaftaran: pendaftaran,
                                        pendaftaranKey: key,
                                      ),
                                ),
                              ).then((newNote) {
                                if (newNote != null) {
                                  setState(() {
                                    pendaftaran['note'] = newNote;
                                    pendaftaran['status'] = 'pending';
                                    pendaftaran['pendingUpdatedAt'] =
                                        DateFormat(
                                          'dd-MM-yyyy',
                                        ).format(DateTime.now());
                                    _applySearch();
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Catatan disimpan')),
                                  );
                                }
                              });
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
                                Icon(
                                  Icons.note_add,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                SizedBox(height: 4),
                                Text(
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
                  padding: EdgeInsets.only(top: 8, right: 36),
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
                    await _updateLeadStatusPendaftaran(key, true);
                    setState(() {
                      pendaftaran['lead'] = true;
                      _applySearch();
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Status lead ditandai')),
                    );
                  } else if (value == 'delete') {
                    _confirmDeleteSingleToTrashPendaftaran(key);
                  }
                },
                itemBuilder:
                    (context) => <PopupMenuEntry<String>>[
                      if (!isLead) ...[
                        PopupMenuItem<String>(
                          value: 'lead',
                          child: Row(
                            children: [
                              Icon(Icons.bookmark, color: Color(0xFF0E5C36)),
                              SizedBox(width: 10),
                              Text(
                                'Lead',
                                style: TextStyle(color: Color(0xFF0E5C36)),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuDivider(),
                      ],
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Color(0xFF0E5C36)),
                            SizedBox(width: 10),
                            Text(
                              'Delete',
                              style: TextStyle(color: Color(0xFF0E5C36)),
                            ),
                          ],
                        ),
                      ),
                    ],
              ),
            ),

            if (widget.status == 'trash')
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
                  itemBuilder:
                      (context) => <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'restore',
                          child: Row(
                            children: [
                              Icon(Icons.restore, color: Color(0xFF0E5C36)),
                              SizedBox(width: 10),
                              Text(
                                'Restore',
                                style: TextStyle(color: Color(0xFF0E5C36)),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuDivider(),
                        PopupMenuItem<String>(
                          value: 'delete_permanent',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Color(0xFF0E5C36)),
                              SizedBox(width: 10),
                              Text(
                                'Delete',
                                style: TextStyle(color: Color(0xFF0E5C36)),
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
    );
  }

  void _confirmDeleteSinglePermanently(String orderKey) {
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
                    'Permanently Delete Data Pengajuan?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Data will be deleted permanently. Delete anyway?',
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
                            await _deleteSingleTrashPermanently(orderKey);
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
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

  void _showExportPendaftaranByStatusDatePicker(String status) async {
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
        final agentStatus = data['status'];
        if (statusUpdatedAt != null && agentStatus == status) {
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
                        "Pilih Tanggal Status \"$status\" untuk diExport",
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
                              onPressed: () async {
                                if (_selectedExportDate != null) {
                                  await _exportPendaftaranByStatusUpdatedAt(
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
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengambil tanggal: $e')));
    }
  }

  Future<void> _exportPendaftaranByStatusUpdatedAt(
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

      if (!snapshot.exists) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak ada data pada tanggal $selectedDate')),
        );
        return;
      }

      final List<Map> agentsToExport = [];

      for (final child in snapshot.children) {
        final data = Map<String, dynamic>.from(child.value as Map);
        if (data['status'] == status) {
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

      sheet.getRangeByIndex(1, 14).columnWidth = 20;
      sheet.getRangeByIndex(1, 15).columnWidth = 20;
      sheet.getRangeByIndex(1, 16).columnWidth = 20;

      for (int i = 0; i < agentsToExport.length; i++) {
        final agent = Map<String, dynamic>.from(agentsToExport[i]);
        final row = i + 2;
        _setExportDialogState(() {
          _exportProgress = (i + 1) / agentsToExport.length;
        });

        await Future.delayed(Duration(milliseconds: 10));

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

      final savedPath = await platform.invokeMethod<String>(
        'saveFileToDownloads',
        {
          'fileName': 'pendaftaran_${selectedDate}_$timestamp.xlsx',
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

  void _confirmDeleteAllTrashPermanently() {
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
                    'Permanently Delete All Data Pengajuan?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Data will be deleted permanently. Delete anyway?',
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
                            _deleteAllTrashPermanently();
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.red, // tombol merah
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
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

  void _deleteAllTrashPermanently() async {
    setState(() => _isLoading = true);

    final ref = FirebaseDatabase.instance.ref().child('agent-form');
    final snapshot = await ref.once();
    final data = snapshot.snapshot.value as Map<dynamic, dynamic>?;

    if (data != null) {
      for (var entry in data.entries) {
        final key = entry.key;
        final pendaftaran = Map<String, dynamic>.from(entry.value);
        if (pendaftaran['trash'] == true) {
          await ref.child(key).remove();
        }
      }
    }

    setState(() => _isLoading = false);
    _fetchPendaftarans();
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

        _buildStatusMenu(),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Data Pendaftaran',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              if (widget.status == 'trash')
                ElevatedButton(
                  onPressed: _confirmDeleteAllTrashPermanently,
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
                      Icon(Icons.delete_forever, size: 16, color: Colors.white),
                      SizedBox(height: 4),
                      Text(
                        'Delete All',
                        style: TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ],
                  ),
                )
              else
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
                      onPressed:
                          () => _showExportPendaftaranByStatusDatePicker(
                            widget.status,
                          ),
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

        SizedBox(height: 12),

        Expanded(
          child:
              _isLoading
                  ? Center(
                    child: CircularProgressIndicator(color: Color(0xFF0E5C36)),
                  )
                  : _pendaftarans.isEmpty
                  ? _buildEmptyState(
                    title: 'No Data Found',
                    subtitle: 'No data pendaftaran found',
                  )
                  : _filteredPendaftarans.isEmpty
                  ? _buildEmptyState(
                    title: 'No Search Results',
                    subtitle: 'No data pendaftaran found',
                  )
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
                            Theme.of(context).textTheme.bodyMedium,
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

  Widget _buildEmptyState({required String title, required String subtitle}) {
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
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade500,
                ),
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
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

  void _confirmDeleteAllRegistrationsToTrashStatus() {
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
                    'Delete All Data Pendaftaran?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Data will first be moved to “Trash Bin”. From there,\nyou can recover them or permanently delete them.',
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
                            _markAllRegistrationsAsTrashedStatus();
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: Color(0xFF0E5C36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
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
      bottomNavigationBar: BottomNavBarPendaftaran(currentRoute: 'status'),
    );
  }
}
