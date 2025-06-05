import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'status_saved_pendaftaran_screen.dart';
import 'pendaftaran_detail_screen.dart';
import 'package:intl/intl.dart';

class SavedPendaftaranScreen extends StatefulWidget {
  @override
  _SavedPendaftaranScreenState createState() => _SavedPendaftaranScreenState();
}

class _SavedPendaftaranScreenState extends State<SavedPendaftaranScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref(
    'agent-form',
  );
  bool _isLoading = false;
  List<Map<dynamic, dynamic>> _leadAgents = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchLeadAgents();
  }

  void _fetchLeadAgents() async {
    setState(() => _isLoading = true);

    final snapshot = await _database.get();
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
            if (!groupedLeadAgents.containsKey(tanggal)) {
              groupedLeadAgents[tanggal] = [];
            }
            value['key'] = key;
            groupedLeadAgents[tanggal]?.add(value);
          }
        }
      });
    }

    setState(() {
      _leadAgents =
          groupedLeadAgents.entries.map((e) {
            return {'date': e.key, 'agents': e.value};
          }).toList();
      _isLoading = false;
    });
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _fetchLeadAgents();
      return;
    }

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

  Future<void> _launchWhatsApp(String phoneNumber) async {
    final uri = Uri.parse('https://wa.me/$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch WhatsApp';
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
      _fetchLeadAgents();
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
                  SizedBox(height: 8),
                  if (!(isLead && status == 'lead'))
                    Text("Status       : $status"),
                ],
              ),
            ),
            if (agent['lead'] == true)
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: () => _showCancelConfirmation(agent['key']),
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
                            style: TextStyle(fontSize: 12, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 6),
                    ElevatedButton(
                      onPressed: () => _showProcessConfirmation(agent['key']),
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
                            style: TextStyle(fontSize: 12, color: Colors.white),
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
                        (_) => StatusSavedPendaftaranScreen(
                          status: item['status'],
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

        SizedBox(height: 12),

        Expanded(
          child:
              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _leadAgents.isEmpty
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
                          'No data lead pendaftaran found',
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
                    itemCount: _leadAgents.length,
                    itemBuilder: (ctx, idx) {
                      final group = _leadAgents[idx];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              'Date: ${group['date'] ?? 'Unknown date'}',
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
