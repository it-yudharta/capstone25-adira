import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'order_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'custom_bottom_nav_bar.dart';

class StatusSavedOrderScreen extends StatefulWidget {
  final String status;
  final String title;

  const StatusSavedOrderScreen({
    Key? key,
    required this.status,
    required this.title,
  }) : super(key: key);

  @override
  _StatusSavedOrderScreenState createState() => _StatusSavedOrderScreenState();
}

class _StatusSavedOrderScreenState extends State<StatusSavedOrderScreen> {
  late String _currentStatus;
  late String _currentTitle;

  final DatabaseReference _database = FirebaseDatabase.instance.ref().child(
    'orders',
  );
  List<Map<dynamic, dynamic>> _filteredOrders = [];
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.status;
    _currentTitle = widget.title;
    _fetchFilteredOrders();
  }

  void _logout() {
    Navigator.pop(context);
  }

  void _applySearch() {
    final query = _searchQuery.toLowerCase();
    setState(() {
      _filteredOrders =
          _filteredOrders.where((order) {
            final name = (order['name'] ?? '').toString().toLowerCase();
            final phone = (order['phone'] ?? '').toString().toLowerCase();
            return name.contains(query) || phone.contains(query);
          }).toList();
    });
  }

  void _fetchFilteredOrders() async {
    setState(() => _isLoading = true);
    final snapshot = await _database.get();
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      final List<Map<dynamic, dynamic>> loaded = [];

      data.forEach((key, value) {
        if (value['lead'] == true && value['status'] == _currentStatus) {
          value['key'] = key;
          loaded.add(value);
        }
      });

      setState(() {
        _filteredOrders = loaded;
        _isLoading = false;
      });
    } else {
      setState(() {
        _filteredOrders = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _launchWhatsApp(String phoneNumber) async {
    final Uri url = Uri.parse("https://wa.me/$phoneNumber");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  Future<void> _updateLeadStatus(String key, bool isLead) async {
    await _database.child(key).update({'lead': isLead});
  }

  Future<void> _confirmDeleteSingleToTrash(String key) async {
    final orderSnapshot = await _database.child(key).get();
    if (orderSnapshot.exists) {
      final orderData = orderSnapshot.value;
      await FirebaseDatabase.instance
          .ref()
          .child('trash')
          .child(key)
          .set(orderData);
      await _database.child(key).remove();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Order dipindahkan ke trash')));

      _fetchFilteredOrders();
    }
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
          children: [
            ...List.generate(statusButtons.length * 2 - 1, (index) {
              if (index.isOdd) return SizedBox(width: 16);
              final item = statusButtons[index ~/ 2];
              final bool isActive = _currentStatus == item['status'];

              return InkWell(
                onTap: () {
                  if (!isActive) {
                    setState(() {
                      _currentStatus = item['status'];
                      _currentTitle = item['label'];
                    });
                    _fetchFilteredOrders();
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF0F4F5),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFF0F4F5),
        elevation: 0,
        foregroundColor: Colors.black,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFFF0F4F5),
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        title: Row(
          children: [
            RichText(
              text: const TextSpan(
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
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.black),
              onPressed: _logout,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: SizedBox(
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
                    borderSide: const BorderSide(
                      color: Color(0xFF0E5C36),
                      width: 1.5,
                    ),
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
          _buildStatusMenu(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_currentStatus != 'trash')
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
                if (_currentStatus != 'trash') SizedBox(width: 8),
                if (_currentStatus != 'trash')
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
          ),
          Expanded(
            child:
                _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _filteredOrders.isEmpty
                    ? Center(
                      child: Text(
                        "Tidak ada order tersimpan dengan status '${_currentStatus}'",
                      ),
                    )
                    : ListView.builder(
                      itemCount: _filteredOrders.length,
                      itemBuilder: (context, index) {
                        final order = _filteredOrders[index];
                        final orderKey = order['key'];
                        final baseStyle =
                            Theme.of(context).textTheme.bodyMedium;
                        return _buildOrderCard(order, orderKey, baseStyle);
                      },
                    ),
          ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNavBar(currentRoute: 'other'),
    );
  }

  Widget _buildOrderCard(Map order, String orderKey, TextStyle? baseStyle) {
    final isLead = order['lead'] == true;
    final String phoneNumber = order['phone'] ?? '-';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) =>
                    OrderDetailScreen(orderData: order, orderKey: order['key']),
          ),
        );
      },
      child: Container(
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
              style: baseStyle,
              child: Padding(
                padding: const EdgeInsets.only(right: 32.0),
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
                      onTap: () async {
                        try {
                          await _launchWhatsApp(phoneNumber);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error launching WhatsApp: $e'),
                            ),
                          );
                        }
                      },
                      child: Text(
                        "No. Telp     : $phoneNumber",
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                    Text("Pekerjaan    : ${order['job'] ?? '-'}"),
                    Text("Pengajuan    : ${order['installment'] ?? '-'}"),
                    SizedBox(height: 8),
                    Text(
                      "Status        : ${order['status'] ?? 'Belum diproses'}",
                    ),
                  ],
                ),
              ),
            ),
            if (isLead)
              Positioned(
                top: 12,
                left: 240,
                child: GestureDetector(
                  onTap: () async {
                    setState(() {
                      order['lead'] = false;
                    });
                    await _updateLeadStatus(orderKey, false);
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
            Positioned(
              top: 0,
              right: 0,
              child: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'lead') {
                    setState(() => order['lead'] = true);
                    _updateLeadStatus(orderKey, true);
                  } else if (value == 'unlead') {
                    setState(() => order['lead'] = false);
                    _updateLeadStatus(orderKey, false);
                  } else if (value == 'delete') {
                    _confirmDeleteSingleToTrash(orderKey);
                  }
                },
                itemBuilder: (BuildContext context) {
                  return [
                    if (!isLead)
                      PopupMenuItem<String>(
                        value: 'lead',
                        child: Text('Mark as Lead'),
                      ),
                    if (isLead)
                      PopupMenuItem<String>(
                        value: 'unlead',
                        child: Text('Remove Lead'),
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
}
