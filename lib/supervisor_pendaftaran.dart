import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import "status_supervisor_pendaftaran.dart";
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

const platform = MethodChannel('com.fundrain.adiraapp/download');

class PendaftaranSupervisor extends StatefulWidget {
  @override
  _PendaftaranSupervisorState createState() => _PendaftaranSupervisorState();
}

class _PendaftaranSupervisorState extends State<PendaftaranSupervisor> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref(
    'agent-form',
  );
  bool _isLoading = false;
  bool _isExporting = false;
  List<Map<dynamic, dynamic>> _agents = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late Map<String, List<Map<dynamic, dynamic>>> groupedOrders;
  List<Map<dynamic, dynamic>> _filteredAgents = [];
  final FocusNode _focusNode = FocusNode();
  late List<String> orderedDates;
  String? _selectedExportDate;
  Set<String> _exportedDates = {};

  @override
  void initState() {
    super.initState();
    _fetchAgents();
  }

  void _fetchAgents() async {
    setState(() => _isLoading = true);
    final snapshot = await _database.get();

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      final Map<String, List<Map<dynamic, dynamic>>> groupedAgents = {};

      data.forEach((key, value) {
        final status = value['status'];
        final isTrashed = value['trash'] == true;
        final isValid =
            !isTrashed && (status == null || status == 'Belum diproses');

        if (isValid) {
          final tanggal = value['tanggal'];
          if (tanggal != null && tanggal is String) {
            if (!groupedAgents.containsKey(tanggal)) {
              groupedAgents[tanggal] = [];
            }
            value['key'] = key;
            groupedAgents[tanggal]?.add(value);
          }
        }
      });

      setState(() {
        _agents =
            groupedAgents.entries.map((entry) {
              return {'date': entry.key, 'agents': entry.value};
            }).toList();

        _filteredAgents =
            _agents
                .expand(
                  (group) => group['agents'] as List<Map<dynamic, dynamic>>,
                )
                .toList();

        _isLoading = false;
      });
    } else {
      setState(() {
        _agents = [];
        _isLoading = false;
      });
    }
  }

  Map<String, List<Map<dynamic, dynamic>>> _groupAgentsByDate(
    List<Map<dynamic, dynamic>> agents,
  ) {
    final Map<String, List<Map<dynamic, dynamic>>> grouped = {};
    for (final agent in agents) {
      final String? tanggal = agent['tanggal'];
      String dateKey;
      try {
        if (tanggal == null || tanggal.isEmpty) throw FormatException();
        DateFormat('d-M-yyyy').parseStrict(tanggal);
        dateKey = tanggal;
      } catch (_) {
        dateKey = 'Tanggal tidak diketahui';
      }
      grouped.putIfAbsent(dateKey, () => []).add(agent);
    }

    final sortedKeys =
        grouped.keys.toList()..sort((a, b) {
          try {
            final dateA = DateFormat('d-M-yyyy').parse(a);
            final dateB = DateFormat('d-M-yyyy').parse(b);
            return dateB.compareTo(dateA);
          } catch (_) {
            return a.compareTo(b);
          }
        });

    orderedDates = sortedKeys;
    return grouped;
  }

  void _applySearch() {
    final query = _searchQuery.toLowerCase();
    _filteredAgents =
        _agents
            .expand((group) => group['agents'] as List<Map<dynamic, dynamic>>)
            .where((agent) {
              final fullName =
                  (agent['fullName'] ?? '').toString().toLowerCase();
              final email = (agent['email'] ?? '').toString().toLowerCase();
              final phone = (agent['phone'] ?? '').toString().toLowerCase();
              return fullName.contains(query) ||
                  email.contains(query) ||
                  phone.contains(query);
            })
            .toList();
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

  Widget _buildAgentCard(Map agent) {
    final String status = agent['status'] ?? 'Belum diproses';
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
      child: DefaultTextStyle.merge(
        style: TextStyle(fontSize: 14, color: Colors.black87),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Nama        : ${agent['fullName'] ?? '-'}",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text("Email         : ${agent['email'] ?? '-'}"),
            SizedBox(height: 4),
            GestureDetector(
              onTap: () => _launchWhatsApp(agent['phone'] ?? ''),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                  children: [
                    TextSpan(text: "No. Telp     : "),
                    TextSpan(
                      text: agent['phone'] ?? '-',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 4),
            Text("Alamat      : ${agent['address'] ?? '-'}"),
            SizedBox(height: 4),
            Text("Kode Pos  : ${agent['postalCode'] ?? '-'}"),
            SizedBox(height: 4),
            Text("Status       : $status"),
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
            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) =>
                            StatusSupervisorPendaftaran(status: item['status']),
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
                    child: Builder(
                      builder: (_) {
                        if (item['icon'] == 'custom_qr_icon') {
                          return SvgPicture.asset(
                            'assets/icon/qr_icon.svg',
                            width: 21,
                            height: 21,
                            color: Color(0xFF0E5C36),
                          );
                        } else if (item['icon'] == 'custom_approve_icon') {
                          return SvgPicture.asset(
                            'assets/icon/approve.svg',
                            width: 21,
                            height: 21,
                            color: Color(0xFF0E5C36),
                          );
                        } else if (item['icon'] == 'custom_reject_icon') {
                          return SvgPicture.asset(
                            'assets/icon/reject.svg',
                            width: 21,
                            height: 21,
                            color: Color(0xFF0E5C36),
                          );
                        } else if (item['icon'] == 'custom_pending_icon') {
                          return SvgPicture.asset(
                            'assets/icon/pending.svg',
                            width: 21,
                            height: 21,
                            color: Color(0xFF0E5C36),
                          );
                        } else if (item['icon'] == 'custom_process_icon') {
                          return SvgPicture.asset(
                            'assets/icon/process.svg',
                            width: 21,
                            height: 21,
                            color: Color(0xFF0E5C36),
                          );
                        } else if (item['icon'] == 'custom_cancel_icon') {
                          return SvgPicture.asset(
                            'assets/icon/cancel.svg',
                            width: 21,
                            height: 21,
                            color: Color(0xFF0E5C36),
                          );
                        } else if (item['icon'] == 'custom_bin_icon') {
                          return SvgPicture.asset(
                            'assets/icon/bin.svg',
                            width: 21,
                            height: 21,
                            color: Color(0xFF0E5C36),
                          );
                        } else {
                          return Icon(
                            item['icon'],
                            size: 21,
                            color: Color(0xFF0E5C36),
                          );
                        }
                      },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset:
          false, // Tambahkan ini untuk mencegah dorongan saat keyboard muncul
      backgroundColor: const Color(0xFFF0F4F5),
      body: SafeArea(child: _buildMainPage()),
    );
  }

  Widget _buildMainPage() {
    final baseStyle = Theme.of(context).textTheme.bodyMedium;
    groupedOrders = _groupAgentsByDate(_filteredAgents);
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
              ElevatedButton(
                onPressed: _showExportSupervisorDatePickerDialog,
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
                  : _filteredAgents.isEmpty
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
                              'No Data Found',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'No data pendaftaran found',
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

                        final agents = groupedOrders[date]!;
                        if (index - currentIndex < agents.length) {
                          final agent = agents[index - currentIndex];
                          return _buildAgentCard(agent);
                        }
                        currentIndex += agents.length;
                      }
                      return SizedBox.shrink();
                    },
                  ),
        ),
      ],
    );
  }

  void _showExportSupervisorDatePickerDialog() async {
    final ref = FirebaseDatabase.instance.ref("agent-form");

    try {
      final snapshot = await ref.get();
      if (!snapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak ada data pendaftaran untuk diekspor')),
        );
        return;
      }

      final uniqueDates = <String>{};
      for (final child in snapshot.children) {
        final data = Map<String, dynamic>.from(child.value as Map);
        final t = data['tanggal'];
        if (t != null) uniqueDates.add(t);
      }

      final sortedDates =
          uniqueDates.toList()..sort((a, b) {
            final da = DateTime.parse(_toIsoDate(a));
            final db = DateTime.parse(_toIsoDate(b));
            return db.compareTo(da);
          });

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
                        "Pilih Tanggal Data Pendaftaran yang ingin diExport",
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
                                  Navigator.pop(context);
                                  await _exportSupervisorByDate(
                                    _selectedExportDate!,
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

  Future<void> _exportSupervisorByDate(String selectedDate) async {
    setState(() => _isExporting = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator()),
    );

    try {
      final ref = FirebaseDatabase.instance.ref("agent-form");
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

      final List<Map<String, dynamic>> items = [];
      for (final ch in snapshot.children) {
        final d = Map<String, dynamic>.from(ch.value as Map);
        d['key'] = ch.key;
        items.add(d);
      }

      final wb = xlsio.Workbook();
      final sheet = wb.worksheets[0];

      final headers = [
        'Tanggal',
        'Status',
        'CancelAt',
        'ProcessAt',
        'PendingAt',
        'RejectAt',
        'ApproveAt',
        'QRAt',
        'Nama',
        'Email',
        'Telepon',
        'Alamat',
        'Kode Pos',
        'KK',
        'KTP',
        'NPWP',
      ];

      for (int col = 0; col < headers.length; col++) {
        sheet.getRangeByIndex(1, col + 1).setText(headers[col]);
      }

      for (int col in [14, 15, 16]) {
        sheet.getRangeByIndex(1, col).columnWidth = 20;
      }

      for (int i = 0; i < items.length; i++) {
        final agent = items[i];
        final row = i + 2;

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
      final bytes = wb.saveAsStream();
      wb.dispose();
      final savedPath = await platform.invokeMethod<
        String
      >('saveFileToDownloads', {
        'fileName':
            'supervisor_pendaftaran_${selectedDate}_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        'bytes': bytes,
      });
      if (savedPath != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('File disimpan di $savedPath')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengekspor: $e')));
    } finally {
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _isExporting = false);
    }
  }

  String _toIsoDate(String date) {
    try {
      final p = date.split('-');
      return '${p[2]}-${p[1].padLeft(2, '0')}-${p[0].padLeft(2, '0')}';
    } catch (_) {
      return date;
    }
  }

  Future<Uint8List?> _downloadImage(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final resp = await http.get(Uri.parse(url));
      return resp.bodyBytes;
    } catch (e) {
      print('Gagal download gambar: $e');
      return null;
    }
  }
}
