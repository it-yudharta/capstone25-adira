import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'order_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'status_supervisor_lead.dart';
import 'circular_loading_indicator.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:http/http.dart' as http;

const platform = MethodChannel('com.fundrain.adiraapp/download');

class LeadSupervisor extends StatefulWidget {
  @override
  _LeadSupervisorState createState() => _LeadSupervisorState();
}

class _LeadSupervisorState extends State<LeadSupervisor> {
  final _database = FirebaseDatabase.instance.ref();
  bool _isLoading = false;
  String _selectedType = 'semua';
  String _searchQuery = '';
  TextEditingController _searchController = TextEditingController();
  final GlobalKey _filterIconKey = GlobalKey();
  bool _isExporting = false;
  double _exportProgress = 0.0;
  void Function(void Function())? _setExportDialogState;
  String? _selectedExportDate;

  List<Map<dynamic, dynamic>> _savedOrders = [];
  List<Map<dynamic, dynamic>> _filteredOrders = [];
  List<Map<String, dynamic>> _leadAgents = [];

  Map<String, List<Map<dynamic, dynamic>>> groupedOrders = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _fetchData() {
    if (_selectedType == 'pengajuan') {
      _fetchSavedOrders();
    } else if (_selectedType == 'pendaftaran') {
      _fetchLeadAgents();
    } else {
      _fetchSavedOrdersAndAgents();
    }
  }

  void _fetchSavedOrdersAndAgents() async {
    setState(() => _isLoading = true);

    final ordersSnapshot = await _database.child('orders').get();
    final agentsSnapshot = await _database.child('agent-form').get();

    final List<Map<dynamic, dynamic>> loadedOrders = [];
    final Map<String, List<Map<dynamic, dynamic>>> groupedLeadAgents = {};

    if (ordersSnapshot.exists) {
      final data = ordersSnapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        final status = value['status'];
        final isTrash = value['trash'] == true;
        final isLead = value['lead'] == true;

        if (!isTrash &&
            isLead &&
            (status == null || status == 'belum diproses')) {
          value['key'] = key;
          loadedOrders.add(value);
        }
      });
    }

    if (agentsSnapshot.exists) {
      final data = agentsSnapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        final isLead = value['lead'] == true;
        final isTrashed = value['trash'] == true;
        final status = value['status'];
        final isValidStatus = status == null || status == 'belum diproses';

        if (isLead && !isTrashed && isValidStatus) {
          final tanggal = value['tanggal'];
          if (tanggal != null && tanggal is String) {
            groupedLeadAgents.putIfAbsent(tanggal, () => []);
            value['key'] = key;
            groupedLeadAgents[tanggal]?.add(value);
          }
        }
      });
    }

    setState(() {
      _savedOrders = loadedOrders;
      _filteredOrders = List.from(_savedOrders);
      groupedOrders = _groupOrdersByDate(_filteredOrders);

      _leadAgents =
          groupedLeadAgents.entries
              .map((e) => {'date': e.key, 'agents': e.value})
              .toList();

      _isLoading = false;
    });
  }

  void _fetchSavedOrders() async {
    setState(() => _isLoading = true);
    final snapshot = await _database.child('orders').get();

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      final loadedOrders = <Map<dynamic, dynamic>>[];

      data.forEach((key, value) {
        final status = value['status'];
        final isTrash = value['trash'] == true;

        if (!isTrash &&
            value['lead'] == true &&
            (status == null || status == 'belum diproses')) {
          value['key'] = key;
          loadedOrders.add(value);
        }
      });

      setState(() {
        _savedOrders = loadedOrders;
        _filteredOrders = List.from(_savedOrders);
        groupedOrders = _groupOrdersByDate(_filteredOrders);
        _isLoading = false;
      });
    } else {
      setState(() {
        _savedOrders = [];
        _filteredOrders = [];
        _isLoading = false;
      });
    }
  }

  void _fetchLeadAgents() async {
    setState(() => _isLoading = true);
    final snapshot = await _database.child('agent-form').get();
    Map<String, List<Map<dynamic, dynamic>>> groupedLeadAgents = {};

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;

      data.forEach((key, value) {
        final isLead = value['lead'] == true;
        final isTrashed = value['trash'] == true;
        final status = value['status'];
        final isValidStatus = status == null || status == 'belum diproses';

        if (isLead && !isTrashed && isValidStatus) {
          final tanggal = value['tanggal'];
          if (tanggal != null && tanggal is String) {
            groupedLeadAgents.putIfAbsent(tanggal, () => []);
            value['key'] = key;
            groupedLeadAgents[tanggal]?.add(value);
          }
        }
      });
    }

    setState(() {
      _leadAgents =
          groupedLeadAgents.entries
              .map((e) => {'date': e.key, 'agents': e.value})
              .toList();
      _isLoading = false;
    });
  }

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

  Map<String, Map<String, List<Map<String, dynamic>>>>
  _groupCombinedDataByDate({
    required List<Map<dynamic, dynamic>> orders,
    required List<Map<dynamic, dynamic>> agents,
  }) {
    final Map<String, Map<String, List<Map<String, dynamic>>>> grouped = {};

    for (var order in orders) {
      final date = order['tanggal'] ?? 'Tanggal tidak diketahui';
      grouped.putIfAbsent(date, () => {});
      grouped[date]!.putIfAbsent('pengajuan', () => []);
      grouped[date]!['pengajuan']!.add(Map<String, dynamic>.from(order));
    }

    for (var agent in agents) {
      final date = agent['tanggal'] ?? 'Tanggal tidak diketahui';
      grouped.putIfAbsent(date, () => {});
      grouped[date]!.putIfAbsent('pendaftaran', () => []);
      grouped[date]!['pendaftaran']!.add(Map<String, dynamic>.from(agent));
    }

    return grouped;
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
    if (_selectedType == 'pengajuan') {
      _applySearchPengajuan();
    } else {
      _applySearchPendaftaran();
    }
  }

  void _applySearchPengajuan() {
    if (_searchQuery.isEmpty) {
      _filteredOrders = List.from(_savedOrders);
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredOrders =
          _savedOrders.where((order) {
            final name = (order['name'] ?? '').toString().toLowerCase();
            final email = (order['email'] ?? '').toString().toLowerCase();
            final agentName =
                (order['agentName'] ?? '').toString().toLowerCase();
            final tanggal = (order['tanggal'] ?? '').toString().toLowerCase();
            return name.contains(query) ||
                email.contains(query) ||
                agentName.contains(query) ||
                tanggal.contains(query);
          }).toList();
    }
    groupedOrders = _groupOrdersByDate(_filteredOrders);
  }

  void _applySearchPendaftaran() {
    if (_searchQuery.isEmpty) {
      _fetchLeadAgents();
    } else {
      setState(() {
        _leadAgents =
            _leadAgents.where((group) {
              final List agents = group['agents'] ?? [];
              return agents.any((agent) {
                final fullName =
                    (agent['fullName'] ?? '').toString().toLowerCase();
                return fullName.contains(_searchQuery.toLowerCase());
              });
            }).toList();
      });
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF0F4F5),
      body: SafeArea(child: _buildMainPage()),
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

            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => StatusSupervisorLead(
                          status: item['status'],
                          type: _selectedType,
                        ),
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
                        switch (item['icon']) {
                          case 'custom_cancel_icon':
                            return SvgPicture.asset(
                              'assets/icon/cancel.svg',
                              width: 21,
                              height: 21,
                              color: Color(0xFF0E5C36),
                            );
                          case 'custom_process_icon':
                            return SvgPicture.asset(
                              'assets/icon/process.svg',
                              width: 21,
                              height: 21,
                              color: Color(0xFF0E5C36),
                            );
                          case 'custom_pending_icon':
                            return SvgPicture.asset(
                              'assets/icon/pending.svg',
                              width: 21,
                              height: 21,
                              color: Color(0xFF0E5C36),
                            );
                          case 'custom_reject_icon':
                            return SvgPicture.asset(
                              'assets/icon/reject.svg',
                              width: 21,
                              height: 21,
                              color: Color(0xFF0E5C36),
                            );
                          case 'custom_approve_icon':
                            return SvgPicture.asset(
                              'assets/icon/approve.svg',
                              width: 21,
                              height: 21,
                              color: Color(0xFF0E5C36),
                            );
                          case 'custom_qr_icon':
                            return SvgPicture.asset(
                              'assets/icon/qr_icon.svg',
                              width: 21,
                              height: 21,
                              color: Color(0xFF0E5C36),
                            );
                          default:
                            return Icon(
                              Icons.help_outline,
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

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Pilih Tipe Data'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.assignment),
                title: Text('Pengajuan'),
                onTap: () {
                  setState(() {
                    _selectedType = 'pengajuan';
                    _searchController.clear();
                    _onSearchChanged('');
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.person),
                title: Text('Pendaftaran'),
                onTap: () {
                  setState(() {
                    _selectedType = 'pendaftaran';
                    _searchController.clear();
                    _onSearchChanged('');
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainPage() {
    final baseStyle = Theme.of(context).textTheme.bodyMedium;
    groupedOrders = _groupOrdersByDate(_filteredOrders);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Container(
            width: 250,
            height: 40,
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
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
                suffixIcon: Icon(Icons.search, color: Colors.grey.shade600),
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
            children: [
              Row(
                children: [
                  PopupMenuButton<String>(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    offset: Offset(0, 40),
                    onSelected: (value) {
                      setState(() {
                        _selectedType = value;
                        _fetchData();
                      });
                    },
                    itemBuilder:
                        (BuildContext context) => [
                          PopupMenuItem<String>(
                            value: 'pengajuan',
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Pengajuan',
                                    style: TextStyle(
                                      color:
                                          _selectedType == 'pengajuan'
                                              ? Color(0xFF0E5C36)
                                              : Colors.black,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 1.2,
                                    ),
                                    color:
                                        _selectedType == 'pengajuan'
                                            ? Color(0xFF0E5C36)
                                            : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuDivider(),
                          PopupMenuItem<String>(
                            value: 'pendaftaran',
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Pendaftaran',
                                    style: TextStyle(
                                      color:
                                          _selectedType == 'pendaftaran'
                                              ? Color(0xFF0E5C36)
                                              : Colors.black,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 1.2,
                                    ),
                                    color:
                                        _selectedType == 'pendaftaran'
                                            ? Color(0xFF0E5C36)
                                            : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                    child: SvgPicture.asset(
                      'assets/icon/filter.svg',
                      color:
                          _selectedType == 'semua'
                              ? Colors.black
                              : Color(0xFF0E5C36),
                    ),
                  ),

                  SizedBox(width: 8),
                  if (_selectedType != 'semua')
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _selectedType[0].toUpperCase() +
                                _selectedType.substring(1),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedType = 'semua';
                                _fetchData();
                              });
                            },
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              ElevatedButton(
                onPressed: _showExportDialog,
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
                  : _buildCombinedListView(),
        ),
      ],
    );
  }

  void _showExportDialog() async {
    final Set<String> uniqueDates = {};

    try {
      if (_selectedType == 'semua') {
        final ordersSnap = await FirebaseDatabase.instance.ref('orders').get();
        for (final child in ordersSnap.children) {
          final data = Map<String, dynamic>.from(child.value as Map);
          if (data['lead'] == true && data['tanggal'] != null) {
            uniqueDates.add(data['tanggal']);
          }
        }

        final agentsSnap =
            await FirebaseDatabase.instance.ref('agent-form').get();
        for (final child in agentsSnap.children) {
          final data = Map<String, dynamic>.from(child.value as Map);
          if (data['lead'] == true && data['tanggal'] != null) {
            uniqueDates.add(data['tanggal']);
          }
        }
      } else {
        final ref = FirebaseDatabase.instance.ref(
          _selectedType == 'pengajuan' ? 'orders' : 'agent-form',
        );
        final snapshot = await ref.get();
        for (final child in snapshot.children) {
          final data = Map<String, dynamic>.from(child.value as Map);
          if (data['lead'] == true && data['tanggal'] != null) {
            uniqueDates.add(data['tanggal']);
          }
        }
      }

      final sortedDates =
          uniqueDates.toList()..sort(
            (a, b) => DateTime.parse(
              _toIsoDate(b),
            ).compareTo(DateTime.parse(_toIsoDate(a))),
          );

      if (sortedDates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak ada data lead untuk diekspor')),
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
                        "Pilih Tanggal Data Lead yang ingin diExport",
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
                                setStateDialog(() => showError = false);
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
                              onPressed: () {
                                if (_selectedExportDate != null) {
                                  if (_selectedType == 'pengajuan') {
                                    _exportPengajuanByDate(
                                      _selectedExportDate!,
                                    );
                                  } else if (_selectedType == 'pendaftaran') {
                                    _exportPendaftaranByDate(
                                      _selectedExportDate!,
                                    );
                                  } else if (_selectedType == 'semua') {
                                    _exportAllByDate(_selectedExportDate!);
                                  }
                                } else {
                                  setStateDialog(() => showError = true);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat tanggal export: $e')),
      );
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

  Future<void> _exportPendaftaranByDate(String selectedDate) async {
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

        if (data['lead'] == true) {
          data['key'] = child.key;
          agentsToExport.add(data);
        }
      }

      if (agentsToExport.isEmpty) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tidak ada data pendaftaran dengan status lead pada tanggal $selectedDate',
            ),
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

      for (int col in [14, 15, 16]) {
        sheet.getRangeByIndex(1, col).columnWidth = 20;
      }

      for (int i = 0; i < agentsToExport.length; i++) {
        final agent = Map<String, dynamic>.from(agentsToExport[i]);
        final row = i + 2;
        _setExportDialogState?.call(() {
          _exportProgress = (i + 1) / agentsToExport.length;
        });

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

  Future<void> _exportPengajuanByDate(String selectedDate) async {
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
      final snapshot =
          await ref.orderByChild("tanggal").equalTo(selectedDate).get();

      if (!snapshot.exists) {
        Navigator.pop(context);
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tidak ada data pengajuan pada $selectedDate'),
          ),
        );
        return;
      }

      final List<Map> dataToExport = [];

      for (final child in snapshot.children) {
        final data = Map<String, dynamic>.from(child.value as Map);
        if (data['lead'] == true) {
          data['key'] = child.key;
          dataToExport.add(data);
        }
      }

      if (dataToExport.isEmpty) {
        Navigator.pop(context);
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tidak ada data pengajuan lead pada $selectedDate'),
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

      for (int i = 0; i < dataToExport.length; i++) {
        final order = Map<String, dynamic>.from(dataToExport[i]);
        final row = i + 2;
        if (_setExportDialogState != null) {
          try {
            _setExportDialogState?.call(() {
              _exportProgress = (i + 1) / dataToExport.length;
            });
          } catch (_) {}
        }

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

        final ktp = await _downloadImage(order['ktp']);
        final bpkb = await _downloadImage(order['bpkb']);
        final kk = await _downloadImage(order['kk']);
        final npwp = await _downloadImage(order['npwp']);
        final slipgaji = await _downloadImage(order['slipgaji']);
        final stnk = await _downloadImage(order['stnk']);

        if (ktp != null) {
          final pic = sheet.pictures.addBase64(row, 23, base64Encode(ktp));
          pic.height = 80;
          pic.width = 120;
        }
        if (bpkb != null) {
          final pic = sheet.pictures.addBase64(row, 24, base64Encode(bpkb));
          pic.height = 80;
          pic.width = 120;
        }
        if (kk != null) {
          final pic = sheet.pictures.addBase64(row, 25, base64Encode(kk));
          pic.height = 80;
          pic.width = 120;
        }
        if (npwp != null) {
          final pic = sheet.pictures.addBase64(row, 26, base64Encode(npwp));
          pic.height = 80;
          pic.width = 120;
        }
        if (slipgaji != null) {
          final pic = sheet.pictures.addBase64(row, 27, base64Encode(slipgaji));
          pic.height = 80;
          pic.width = 120;
        }
        if (stnk != null) {
          final pic = sheet.pictures.addBase64(row, 28, base64Encode(stnk));
          pic.height = 80;
          pic.width = 120;
        }
      }

      final bytes = workbook.saveAsStream();
      workbook.dispose();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      try {
        final savedPath = await platform
            .invokeMethod<String>('saveFileToDownloads', {
              'fileName': 'saved_pengajuan_${selectedDate}_$timestamp.xlsx',
              'bytes': bytes,
            });

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

  Future<void> _exportAllByDate(String selectedDate) async {
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

    try {
      final pengajuanList = <Map<String, dynamic>>[];
      final pendaftaranList = <Map<String, dynamic>>[];

      final ordersSnap =
          await FirebaseDatabase.instance
              .ref('orders')
              .orderByChild('tanggal')
              .equalTo(selectedDate)
              .get();

      final agentsSnap =
          await FirebaseDatabase.instance
              .ref('agent-form')
              .orderByChild('tanggal')
              .equalTo(selectedDate)
              .get();

      if (agentsSnap.exists) {
        for (final child in agentsSnap.children) {
          final agentData = Map<String, dynamic>.from(child.value as Map);
          if (agentData['lead'] == true) {
            agentData['key'] = child.key;
            pendaftaranList.add(agentData);
          }
        }
      }

      if (ordersSnap.exists) {
        for (final child in ordersSnap.children) {
          final data = Map<String, dynamic>.from(child.value as Map);
          if (data['lead'] == true) {
            data['key'] = child.key;
            pengajuanList.add(data);
          }
        }
      }

      if (pengajuanList.isEmpty && pendaftaranList.isEmpty) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tidak ada data pengajuan/pendaftaran lead pada $selectedDate',
            ),
          ),
        );
        return;
      }

      final workbook = xlsio.Workbook();
      final pengajuanSheet = workbook.worksheets[0];
      pengajuanSheet.name = 'Pengajuan';
      final pendaftaranSheet = workbook.worksheets.addWithName('Pendaftaran');

      final pengajuanHeaders = [
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
      ];

      for (int i = 0; i < pengajuanHeaders.length; i++) {
        pengajuanSheet.getRangeByIndex(1, i + 1).setText(pengajuanHeaders[i]);
      }

      for (int i = 0; i < pengajuanList.length; i++) {
        final order = pengajuanList[i];
        final row = i + 2;
        _setExportDialogState?.call(() {
          _exportProgress = (i + 1) / pengajuanList.length;
        });

        pengajuanSheet.getRangeByIndex(row, 1).setText(order['tanggal'] ?? '');
        pengajuanSheet.getRangeByIndex(row, 2).setText(order['status'] ?? '');
        pengajuanSheet
            .getRangeByIndex(row, 3)
            .setText(order['cancelUpdatedAt'] ?? '');
        pengajuanSheet
            .getRangeByIndex(row, 4)
            .setText(order['processUpdatedAt'] ?? '');
        pengajuanSheet
            .getRangeByIndex(row, 5)
            .setText(order['pendingUpdatedAt'] ?? '');
        pengajuanSheet
            .getRangeByIndex(row, 6)
            .setText(order['rejectUpdatedAt'] ?? '');
        pengajuanSheet
            .getRangeByIndex(row, 7)
            .setText(order['approveUpdatedAt'] ?? '');
        pengajuanSheet.getRangeByIndex(row, 8).setText(order['name'] ?? '');
        pengajuanSheet.getRangeByIndex(row, 9).setText(order['email'] ?? '');
        pengajuanSheet.getRangeByIndex(row, 10).setText(order['phone'] ?? '');
        pengajuanSheet.getRangeByIndex(row, 11).setText(order['job'] ?? '');
        pengajuanSheet.getRangeByIndex(row, 12).setText(order['income'] ?? '');
        pengajuanSheet.getRangeByIndex(row, 13).setText(order['item'] ?? '');
        pengajuanSheet.getRangeByIndex(row, 14).setText(order['merk'] ?? '');
        pengajuanSheet.getRangeByIndex(row, 15).setText(order['nominal'] ?? '');
        pengajuanSheet
            .getRangeByIndex(row, 16)
            .setText(order['installment'] ?? '');
        pengajuanSheet.getRangeByIndex(row, 17).setText(order['dp'] ?? '');
        pengajuanSheet
            .getRangeByIndex(row, 18)
            .setText(order['domicile'] ?? '');
        pengajuanSheet
            .getRangeByIndex(row, 19)
            .setText(order['postalCode'] ?? '');
        pengajuanSheet
            .getRangeByIndex(row, 20)
            .setText(order['agentName'] ?? '');
        pengajuanSheet
            .getRangeByIndex(row, 21)
            .setText(order['agentEmail'] ?? '');
        pengajuanSheet
            .getRangeByIndex(row, 22)
            .setText(order['agentPhone'] ?? '');
      }

      final pendaftaranHeaders = [
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

      for (int i = 0; i < pendaftaranHeaders.length; i++) {
        pendaftaranSheet
            .getRangeByIndex(1, i + 1)
            .setText(pendaftaranHeaders[i]);
      }

      for (int i = 0; i < pendaftaranList.length; i++) {
        final agent = pendaftaranList[i];
        final row = i + 2;
        _setExportDialogState?.call(() {
          _exportProgress = (i + 1) / pendaftaranList.length;
        });

        pendaftaranSheet
            .getRangeByIndex(row, 1)
            .setText(agent['tanggal'] ?? '');
        pendaftaranSheet.getRangeByIndex(row, 2).setText(agent['status'] ?? '');
        pendaftaranSheet
            .getRangeByIndex(row, 3)
            .setText(agent['cancelUpdatedAt'] ?? '');
        pendaftaranSheet
            .getRangeByIndex(row, 4)
            .setText(agent['processUpdatedAt'] ?? '');
        pendaftaranSheet
            .getRangeByIndex(row, 5)
            .setText(agent['pendingUpdatedAt'] ?? '');
        pendaftaranSheet
            .getRangeByIndex(row, 6)
            .setText(agent['rejectUpdatedAt'] ?? '');
        pendaftaranSheet
            .getRangeByIndex(row, 7)
            .setText(agent['approveUpdatedAt'] ?? '');
        pendaftaranSheet
            .getRangeByIndex(row, 8)
            .setText(agent['qr_givenUpdatedAt'] ?? '');
        pendaftaranSheet
            .getRangeByIndex(row, 9)
            .setText(agent['fullName'] ?? '');
        pendaftaranSheet.getRangeByIndex(row, 10).setText(agent['email'] ?? '');
        pendaftaranSheet.getRangeByIndex(row, 11).setText(agent['phone'] ?? '');
        pendaftaranSheet
            .getRangeByIndex(row, 12)
            .setText(agent['address'] ?? '');
        pendaftaranSheet
            .getRangeByIndex(row, 13)
            .setText(agent['postalCode'] ?? '');

        final kkImage = await _downloadImage(agent['kk']);
        final ktpImage = await _downloadImage(agent['ktp']);
        final npwpImage = await _downloadImage(agent['npwp']);

        for (int col in [14, 15, 16]) {
          pendaftaranSheet.getRangeByIndex(1, col).columnWidth = 20;
        }

        if (kkImage != null) {
          final pic = pendaftaranSheet.pictures.addBase64(
            row,
            14,
            base64Encode(kkImage),
          );
          pic.height = 80;
          pic.width = 120;
        }
        if (ktpImage != null) {
          final pic = pendaftaranSheet.pictures.addBase64(
            row,
            15,
            base64Encode(ktpImage),
          );
          pic.height = 80;
          pic.width = 120;
        }
        if (npwpImage != null) {
          final pic = pendaftaranSheet.pictures.addBase64(
            row,
            16,
            base64Encode(npwpImage),
          );
          pic.height = 80;
          pic.width = 120;
        }
      }

      final bytes = workbook.saveAsStream();
      workbook.dispose();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final savedPath = await platform.invokeMethod<String>(
        'saveFileToDownloads',
        {
          'fileName': 'saved_semua_${selectedDate}_$timestamp.xlsx',
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

  Widget _buildEmptyState(String message) {
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
                'No Data Found',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade500,
                ),
              ),
              SizedBox(height: 4),
              Text(
                message,
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

  Widget _buildAgentCard(Map agent) {
    final String status = agent['status'] ?? 'Belum diproses';
    final bool isLead = agent['lead'] == true;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
            style: const TextStyle(fontSize: 14, color: Colors.black87),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Nama        : ${agent['fullName'] ?? '-'}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text("Email         : ${agent['email'] ?? '-'}"),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _launchWhatsApp(agent['phone'] ?? ''),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      children: [
                        const TextSpan(text: "No. Telp     : "),
                        TextSpan(
                          text: agent['phone'] ?? '-',
                          style: const TextStyle(color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text("Alamat      : ${agent['address'] ?? '-'}"),
                const SizedBox(height: 4),
                Text("Kode Pos  : ${agent['postalCode'] ?? '-'}"),
                const SizedBox(height: 4),
                Text("Status       : $status"),
              ],
            ),
          ),

          if (isLead)
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
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
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map order, String key, TextStyle? baseStyle) {
    final String phoneNumber = order['phone'] ?? '-';
    final bool isLead = order['lead'] == true;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(orderData: order, orderKey: key),
          ),
        );
      },
      child: Container(
        width: double.infinity,
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
              style: TextStyle(fontSize: 14, color: Colors.black87),
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
                    onTap: () => _launchWhatsApp(phoneNumber),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                        children: [
                          TextSpan(text: "No. Telp      : "),
                          TextSpan(
                            text: phoneNumber,
                            style: TextStyle(color: Colors.blue),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Text("Pekerjaan  : ${order['job'] ?? '-'}"),
                  Text("Pengajuan : ${order['installment'] ?? '-'}"),
                  SizedBox(height: 8),
                  Text(
                    "Status        : ${order['status'] ?? 'Belum diproses'}",
                  ),
                ],
              ),
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

  List<Widget> _buildPengajuanListItems() {
    return groupedOrders.entries.expand((entry) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Text(
            'Date: ${entry.key}',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        ...entry.value.map((order) {
          return _buildOrderCard(
            order,
            order['key'] as String,
            Theme.of(context).textTheme.bodyMedium,
          );
        }).toList(),
      ];
    }).toList();
  }

  List<Widget> _buildPendaftaranListItems() {
    return _leadAgents.expand((group) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Text(
            'Date: ${group['date']}',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        ...(group['agents'] as List)
            .map((agent) => _buildAgentCard(agent))
            .toList(),
      ];
    }).toList();
  }

  Widget _buildCombinedListView() {
    final orders =
        (_selectedType == 'pendaftaran')
            ? <Map<dynamic, dynamic>>[]
            : _filteredOrders.cast<Map<dynamic, dynamic>>();

    final agents =
        (_selectedType == 'pengajuan')
            ? <Map<dynamic, dynamic>>[]
            : _leadAgents
                .expand((e) => (e['agents'] as List))
                .map((a) => a as Map<dynamic, dynamic>)
                .toList();

    final grouped = _groupCombinedDataByDate(orders: orders, agents: agents);

    if (grouped.isEmpty) return _buildEmptyState('No data lead found');

    final sortedDates =
        grouped.keys.toList()..sort(
          (a, b) => DateFormat(
            'd-M-yyyy',
          ).parse(b, true).compareTo(DateFormat('d-M-yyyy').parse(a, true)),
        );

    return ListView(
      padding: EdgeInsets.only(bottom: 20),
      children:
          sortedDates.expand((date) {
            final children = <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8,
                ),
                child: Text(
                  'Date: $date',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ];

            final data = grouped[date]!;

            if (data.containsKey('pengajuan')) {
              children.addAll(
                data['pengajuan']!.map(
                  (order) => _buildOrderCard(
                    order,
                    order['key'],
                    Theme.of(context).textTheme.bodyMedium!,
                  ),
                ),
              );
            }

            if (data.containsKey('pendaftaran')) {
              children.addAll(
                data['pendaftaran']!.map((agent) => _buildAgentCard(agent)),
              );
            }

            return children;
          }).toList(),
    );
  }
}
