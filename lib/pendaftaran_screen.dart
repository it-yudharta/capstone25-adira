import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'status_pendaftaran_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'pendaftaran_detail_screen.dart';

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
        final tanggal = value['tanggal'];
        if (tanggal != null && tanggal is String) {
          if (!groupedAgents.containsKey(tanggal)) {
            groupedAgents[tanggal] = [];
          }
          value['key'] = key;
          groupedAgents[tanggal]?.add(value);
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

  Widget _buildAgentCard(Map agent) {
    final String status = agent['status'] ?? 'Belum diproses';

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
                  Text("Alamat      : ${agent['address'] ?? '-'}"),
                  Text("Email         : ${agent['email'] ?? '-'}"),
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
                  Text("Kode Pos  : ${agent['postalCode'] ?? '-'}"),
                  SizedBox(height: 8),
                  Text("Status        : $status"),
                  SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
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
      {'label': 'Reject', 'status': 'reject', 'icon': Icons.block},
      {'label': 'Approve', 'status': 'approve', 'icon': Icons.check_circle},
      {'label': 'QR Given', 'status': 'qr_given', 'icon': Icons.qr_code},
      {'label': 'Trash Bin', 'status': 'trash_bin', 'icon': Icons.delete},
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
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
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
                    Icon(Icons.delete_outline, size: 16, color: Colors.white),
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
                  : _agents.isEmpty
                  ? Center(child: Text('Belum ada data pendaftaran'))
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F5),
      body: _buildMainPage(),
    );
  }
}
