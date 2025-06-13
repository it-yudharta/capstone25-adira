import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import "status_supervisor_pendaftaran.dart";
import 'package:intl/intl.dart';

class PendaftaranSupervisor extends StatefulWidget {
  @override
  _PendaftaranSupervisorState createState() => _PendaftaranSupervisorState();
}

class _PendaftaranSupervisorState extends State<PendaftaranSupervisor> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref(
    'agent-form',
  );
  bool _isLoading = false;
  List<Map<dynamic, dynamic>> _agents = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late Map<String, List<Map<dynamic, dynamic>>> groupedOrders;
  List<Map<dynamic, dynamic>> _filteredAgents = [];
  final FocusNode _focusNode = FocusNode();
  late List<String> orderedDates;

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
      {'label': 'Cancel', 'status': 'cancel', 'icon': Icons.cancel},
      {'label': 'Process', 'status': 'process', 'icon': Icons.hourglass_bottom},
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F5),
      body: _buildMainPage(),
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
                onPressed: () {},
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
                  ? Center(child: Text("Tidak ada data ditemukan"))
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
}
