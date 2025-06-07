import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'status_pendaftaran_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'pendaftaran_detail_screen.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:http/http.dart' as http;
import 'dart:convert';

const platform = MethodChannel('com.fundrain.adiraapp/download');

class PendaftaranScreen extends StatefulWidget {
  @override
  _PendaftaranScreenState createState() => _PendaftaranScreenState();
}

class _PendaftaranScreenState extends State<PendaftaranScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref(
    'agent-form',
  );
  bool _isLoading = false;
  List<Map<dynamic, dynamic>> _agents = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _fetchAgents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        _isLoading = false;
      });
    } else {
      setState(() {
        _agents = [];
        _isLoading = false;
      });
    }
  }

  void _applySearch() {
    _agents =
        _agents.where((group) {
          return group['agents'].any((agent) {
            final query = _searchQuery.toLowerCase();
            final fullName = (agent['fullName'] ?? '').toString().toLowerCase();
            final email = (agent['email'] ?? '').toString().toLowerCase();
            final phone = (agent['phone'] ?? '').toString().toLowerCase();
            return fullName.contains(query) ||
                email.contains(query) ||
                phone.contains(query);
          });
        }).toList();
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

  void _updateAgentStatus(String agentKey, String newStatus) async {
    final now = DateTime.now();
    final formattedDate = DateFormat('dd-MM-yyyy').format(now);

    Map<String, dynamic> updates = {
      'status': newStatus,
      '${newStatus}UpdatedAt': formattedDate,
    };

    try {
      await _database.child(agentKey).update(updates);
      _fetchAgents();
    } catch (e) {
      print("Gagal memperbarui status: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memperbarui status')));
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

  void _showProcessConfirmation(String agentKey) {
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
                    'Process Pendaftaran?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Pendaftaran will be processed and\nmoved to “Process”.',
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
                            _updateAgentStatus(agentKey, 'process');
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

  void _confirmDeleteSinglePendaftaranToTrash(String key) {
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
                    _fetchAgents();
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

  Widget _buildAgentCard(Map agent) {
    final String status = agent['status'] ?? 'Belum diproses';
    final bool isLead = agent['lead'] == true;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PendaftaranDetailScreen(agentData: agent),
          ),
        );
      },
      child: Container(
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
        child: Stack(
          children: [
            DefaultTextStyle.merge(
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
                    onTap: () async {
                      try {
                        await _launchWhatsApp(agent['phone'] ?? '');
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
                  SizedBox(height: 8),
                  if (!(isLead && status == 'lead'))
                    Text("Status       : $status"),
                  SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed:
                              () => _showCancelConfirmation(agent['key']),
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
                              () => _showProcessConfirmation(agent['key']),
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
                                Icons.hourglass_top,
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

            if (agent['lead'] == true)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.only(top: 8, right: 36),
                  child: GestureDetector(
                    onTap: () async {
                      setState(() => agent['lead'] = false);
                      await _updateLeadStatusPendaftaran(agent['key'], false);
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
                onSelected: (value) async {
                  if (value == 'lead') {
                    setState(() => agent['lead'] = true);
                    await _updateLeadStatusPendaftaran(agent['key'], true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Status lead ditandai')),
                    );
                  } else if (value == 'delete') {
                    _confirmDeleteSinglePendaftaranToTrash(agent['key']);
                  }
                },
                itemBuilder: (BuildContext context) {
                  return [
                    if (agent['lead'] != true)
                      PopupMenuItem<String>(value: 'lead', child: Text('Lead')),
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

  Future<void> _updateLeadStatusPendaftaran(
    String agentKey,
    bool isLead,
  ) async {
    final agentRef = _database.child(agentKey);
    try {
      await agentRef.update({'lead': isLead});
    } catch (error) {
      print("Gagal mengubah status lead: $error");
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
      {'label': 'Reject', 'status': 'reject', 'icon': Icons.block},
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(statusButtons.length * 2 - 1, (index) {
            if (index.isOdd) return SizedBox(width: 16);
            final item = statusButtons[index ~/ 2];
            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => StatusPendaftaranScreen(status: item['status']),
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Container(
            width: 250,
            height: 40,
            child: TextField(
              controller: _searchController,
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
                  icon: Icon(Icons.search, color: Colors.grey.shade600),
                  onPressed: () {
                    FocusScope.of(context).requestFocus(FocusNode());
                  },
                ),
              ),
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
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _confirmDeleteAllRegistrationsToTrash,
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
                      _showExportAgentDatePickerDialog();
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

        SizedBox(height: 12),

        Expanded(
          child:
              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _agents.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/EmptyState.png',
                          width: 300,
                          height: 200,
                          fit: BoxFit.contain,
                          alignment: Alignment.topCenter,
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
                  )
                  : ListView.builder(
                    itemCount: _agents.length,
                    itemBuilder: (ctx, idx) {
                      final group = _agents[idx];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              'Date: ${group['date']}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          ...group['agents']
                              .map<Widget>((agent) => _buildAgentCard(agent))
                              .toList(),
                        ],
                      );
                    },
                  ),
        ),
      ],
    );
  }

  void _showExportAgentDatePickerDialog() async {
    final ref = FirebaseDatabase.instance.ref("agent-form");

    try {
      final snapshot = await ref.get();

      if (!snapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak ada data pendaftaran untuk diekspor')),
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
              title: Text("Pilih Tanggal untuk Export Pendaftaran"),
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
                        _exportAgentsByDate(date);
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

  Future<void> _exportAgentsByDate(String selectedDate) async {
    setState(() => _isExporting = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator()),
    );

    final ref = FirebaseDatabase.instance.ref("agent-form");

    try {
      final snapshot =
          await ref.orderByChild("tanggal").equalTo(selectedDate).get();

      if (!snapshot.exists) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tidak ada data pendaftaran pada tanggal $selectedDate',
            ),
          ),
        );
        return;
      }

      final List<Map> agentsToExport = [];

      for (final child in snapshot.children) {
        final data = Map<String, dynamic>.from(child.value as Map);

        // Kalau ingin filter lead juga, aktifkan ini:
        // if (data['lead'] == true) {
        data['key'] = child.key;
        agentsToExport.add(data);
        // }
      }

      if (agentsToExport.isEmpty) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tidak ada data pendaftaran pada tanggal $selectedDate',
            ),
          ),
        );
        return;
      }

      final workbook = xlsio.Workbook();
      final sheet = workbook.worksheets[0];

      // Header sama dengan saved pendaftaran
      final headers = [
        'Tanggal',
        'Status',
        'Tanggal Cancel',
        'Tanggal Process',
        'Tanggal Pending',
        'Tanggal Reject',
        'Tanggal Approve',
        'Tanggal QR Given',
        'Nama Lengkap',
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

      // Atur lebar kolom gambar
      for (int col in [14, 15, 16]) {
        sheet.getRangeByIndex(1, col).columnWidth = 20;
      }

      for (int i = 0; i < agentsToExport.length; i++) {
        final agent = Map<String, dynamic>.from(agentsToExport[i]);
        final row = i + 2;

        sheet.getRangeByIndex(row, 1).rowHeight = 80;
        sheet.getRangeByIndex(row, 1).setText(agent['tanggal'] ?? '');
        sheet.getRangeByIndex(row, 2).setText(agent['status'] ?? '');

        // Isi kolom tanggal status update
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

        // Tambah gambar
        final kkImage = await _downloadImage(agent['kk']);
        final ktpImage = await _downloadImage(agent['ktp']);
        final npwpImage = await _downloadImage(agent['npwp']);

        if (kkImage != null) {
          final picture = sheet.pictures.addBase64(
            row,
            14,
            base64Encode(kkImage),
          );
          picture.height = 80;
          picture.width = 120;
        }
        if (ktpImage != null) {
          final picture = sheet.pictures.addBase64(
            row,
            15,
            base64Encode(ktpImage),
          );
          picture.height = 80;
          picture.width = 120;
        }
        if (npwpImage != null) {
          final picture = sheet.pictures.addBase64(
            row,
            16,
            base64Encode(npwpImage),
          );
          picture.height = 80;
          picture.width = 120;
        }
      }

      final bytes = workbook.saveAsStream();
      workbook.dispose();

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      try {
        final savedPath = await platform.invokeMethod<String>(
          'saveFileToDownloads',
          {
            'fileName': 'pendaftaran_${selectedDate}_$timestamp.xlsx',
            'bytes': bytes,
          },
        );

        if (savedPath != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('File berhasil disimpan di $savedPath')),
          );
        }
      } on PlatformException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan file: ${e.message}')),
        );
      }

      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _isExporting = false);
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

  void _confirmDeleteAllRegistrationsToTrash() {
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
                  _markAllRegistrationsAsTrashed();
                },
                child: Text('Ya, Hapus'),
              ),
            ],
          ),
    );
  }

  void _markAllRegistrationsAsTrashed() async {
    final now = DateTime.now();
    final formattedDate = DateFormat('dd-MM-yyyy').format(now);

    int trashedCount = 0;

    for (final group in _agents) {
      final agents = group['agents'];
      for (final agent in agents) {
        final isLead = agent['lead'] == true;
        final key = agent['key'];

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
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Berhasil menandai $trashedCount data sebagai trash'),
        ),
      );
      _fetchAgents();
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
