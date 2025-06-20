import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'navbar_supervisor.dart';
import 'package:flutter/services.dart';

class StatusSupervisorLead extends StatefulWidget {
  final String status;
  final String type;

  const StatusSupervisorLead({
    super.key,
    required this.status,
    required this.type,
  });

  @override
  _StatusSupervisorLeadState createState() => _StatusSupervisorLeadState();
}

class _StatusSupervisorLeadState extends State<StatusSupervisorLead> {
  final _database = FirebaseDatabase.instance.ref();
  bool _isLoading = false;
  List<Map<dynamic, dynamic>> _filteredData = [];
  Map<String, Map<String, List<Map<String, dynamic>>>> groupedData = {};
  late String _currentStatus;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = '';
  String _selectedType = 'semua';

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      setState(() {
        groupedData = groupByDateAndSource(_filteredData);
      });
      return;
    }

    final filtered =
        _filteredData.where((item) {
          final name = item['name'] ?? item['fullName'] ?? '';
          final email = item['email'] ?? '';
          final phone = item['phone'] ?? '';
          return name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              phone.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

    setState(() {
      groupedData = groupByDateAndSource(filtered);
    });
  }

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.status;
    _selectedType = widget.type ?? 'semua';
    _fetchFilteredData();
  }

  void _fetchFilteredData() async {
    setState(() => _isLoading = true);
    final List<Map<dynamic, dynamic>> result = [];

    if (_selectedType == 'pengajuan' || _selectedType == 'semua') {
      final ordersSnapshot = await _database.child('orders').get();
      if (ordersSnapshot.exists) {
        final data = ordersSnapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final status = value['status'];
          final isTrash = value['trash'] == true;
          final isLead = value['lead'] == true;
          if (_currentStatus == 'trash') {
            if (isLead && isTrash) {
              value['key'] = key;
              value['source'] = 'pengajuan';
              result.add(Map<String, dynamic>.from(value));
            }
          } else {
            if (status == _currentStatus && isLead && !isTrash) {
              value['key'] = key;
              value['source'] = 'pengajuan';
              result.add(Map<String, dynamic>.from(value));
            }
          }
        });
      }
    }

    if (_selectedType == 'pendaftaran' || _selectedType == 'semua') {
      final agentsSnapshot = await _database.child('agent-form').get();
      if (agentsSnapshot.exists) {
        final data = agentsSnapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final status = value['status'];
          final isTrash = value['trash'] == true;
          final isLead = value['lead'] == true;

          if (_currentStatus == 'trash') {
            if (isLead && isTrash) {
              value['key'] = key;
              value['source'] = 'pendaftaran';
              result.add(Map<String, dynamic>.from(value));
            }
          } else {
            if (status == _currentStatus && isLead && !isTrash) {
              value['key'] = key;
              value['source'] = 'pendaftaran';
              result.add(Map<String, dynamic>.from(value));
            }
          }
        });
      }
    }

    setState(() {
      _filteredData = result;
      groupedData = groupByDateAndSource(_filteredData);
      _isLoading = false;
    });
  }

  Map<String, Map<String, List<Map<String, dynamic>>>> groupByDateAndSource(
    List<Map> data,
  ) {
    final Map<String, Map<String, List<Map<String, dynamic>>>> grouped = {};

    for (var item in data) {
      final source = item['source'] ?? 'pengajuan';
      final tanggal = item['tanggal'] ?? 'Tanggal tidak diketahui';

      grouped.putIfAbsent(tanggal, () => {});
      grouped[tanggal]!.putIfAbsent(source, () => []);
      grouped[tanggal]![source]!.add(Map<String, dynamic>.from(item));
    }

    return grouped;
  }

  void _logout() {
    Navigator.pushReplacementNamed(context, '/login');
  }

  String normalizePhoneNumber(String phone) {
    if (phone.startsWith('0')) {
      return '62${phone.substring(1)}';
    }
    return phone;
  }

  Future<void> _launchWhatsApp(String phoneNumber) async {
    final normalizedPhone = normalizePhoneNumber(phoneNumber);
    final uri = Uri.parse('https://wa.me/$normalizedPhone');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Tidak dapat membuka WhatsApp')));
    }
  }

  void _showRejectConfirmation(String key) {
    // TODO: Implementasi reject
  }

  void _showApproveConfirmation(String key) {
    // TODO: Implementasi approve
  }
  void _changeStatus(String newStatus) {
    setState(() {
      _currentStatus = newStatus;
      _fetchFilteredData();
    });
  }

  Widget _buildCard(Map data) {
    final String source = data['source'] ?? 'pengajuan';
    final String status = data['status'] ?? 'Belum diproses';
    final String phone = data['phone'] ?? '-';
    final bool isLead = data['lead'] == true;

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
      child: Stack(
        children: [
          DefaultTextStyle.merge(
            style: TextStyle(fontSize: 14, color: Colors.black87),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Nama        : ${data['fullName'] ?? data['name'] ?? '-'}",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text("Email         : ${data['email'] ?? '-'}"),
                SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _launchWhatsApp(phone),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(color: Colors.black87),
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
                if (source == 'pendaftaran') ...[
                  SizedBox(height: 4),
                  Text("Alamat      : ${data['address'] ?? '-'}"),
                  SizedBox(height: 4),
                  Text("Kode Pos  : ${data['postalCode'] ?? '-'}"),
                ] else ...[
                  SizedBox(height: 4),
                  Text("Alamat      : ${data['domicile'] ?? '-'}"),
                  SizedBox(height: 4),
                  Text("Pekerjaan  : ${data['job'] ?? '-'}"),
                  SizedBox(height: 4),
                  Text("Pengajuan : ${data['installment'] ?? '-'}"),
                ],
                SizedBox(height: 4),
                Text(
                  "Status       : $status",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (data['note'] != null && data['note'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text("Note          : ${data['note']}"),
                  ),
                if (status.toLowerCase() == 'pending' &&
                    widget.status != 'trash')
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () => _showRejectConfirmation(data['key']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF0E5C36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.cancel, size: 16, color: Colors.white),
                              SizedBox(height: 4),
                              Text('Reject', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        SizedBox(width: 6),
                        ElevatedButton(
                          onPressed:
                              () => _showApproveConfirmation(data['key']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF0E5C36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 16,
                                color: Colors.white,
                              ),
                              SizedBox(height: 4),
                              Text('Approve', style: TextStyle(fontSize: 12)),
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
                padding: EdgeInsets.only(top: 8, right: 8),
                child: Icon(Icons.bookmark, color: Color(0xFF0E5C36), size: 24),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map order) {
    final phone = order['phone'] ?? '-';
    final status = order['status'] ?? 'Belum diproses';
    final isLead = order['lead'] == true;
    final key = order['key'];

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 4)],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Nama        : ${order['name'] ?? '-'}",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text("Email         : ${order['email'] ?? '-'}"),
              SizedBox(height: 4),
              GestureDetector(
                onTap: () => _launchWhatsApp(phone),
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
              Text("Alamat      : ${order['domicile'] ?? '-'}"),
              SizedBox(height: 4),
              Text("Pekerjaan  : ${order['job'] ?? '-'}"),
              SizedBox(height: 4),
              Text("Pengajuan : ${order['installment'] ?? '-'}"),
              SizedBox(height: 4),
              Text(
                "Status        : $status",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (order['note'] != null && order['note'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text("Note           : ${order['note']}"),
                ),
              if (status == 'pending' && _currentStatus != 'trash')
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () => _showRejectConfirmation(key),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF0E5C36),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.cancel, size: 16, color: Colors.white),
                            SizedBox(height: 4),
                            Text('Reject', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      SizedBox(width: 6),
                      ElevatedButton(
                        onPressed: () => _showApproveConfirmation(key),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF0E5C36),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Colors.white,
                            ),
                            SizedBox(height: 4),
                            Text('Approve', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (isLead)
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.only(top: 8, right: 8),
                child: Icon(Icons.bookmark, color: Color(0xFF0E5C36), size: 24),
              ),
            ),
        ],
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
            final bool isActive = _currentStatus == item['status'];

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
                        _fetchFilteredData();
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
                                _fetchFilteredData();
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
                onPressed: () => print("Export logic here"),
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
                  : groupedData.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                    children:
                        groupedData.entries.map((entry) {
                          final tanggal = entry.key;
                          final sources = entry.value;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  4,
                                ),
                                child: Text(
                                  'Date: $tanggal',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              ...sources.entries.expand((sourceEntry) {
                                return sourceEntry.value.map((data) {
                                  final source = data['source'];
                                  if (source == 'pengajuan') {
                                    return _buildOrderCard(data);
                                  } else {
                                    return _buildCard(data);
                                  }
                                });
                              }).toList(),
                            ],
                          );
                        }).toList(),
                  ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
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
                'No data lead found',
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
      bottomNavigationBar: BottomNavBarSupervisor(currentRoute: 'status'),
    );
  }
}
