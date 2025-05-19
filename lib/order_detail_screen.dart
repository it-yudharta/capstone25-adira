import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderDetailScreen extends StatelessWidget {
  final Map orderData;
  final String orderKey;

  OrderDetailScreen({required this.orderData, required this.orderKey});

  void showImageDialog(BuildContext context, String label, String url) {
    showDialog(
      context: context,
      builder:
          (_) => Dialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    label,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return SizedBox(
                      height: 150,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder:
                      (context, error, stackTrace) => Padding(
                        padding: EdgeInsets.all(16),
                        child: Text("Gagal memuat gambar"),
                      ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Tutup'),
                ),
              ],
            ),
          ),
    );
  }

  Widget buildImageRow(BuildContext context, String label, String url) {
    String buttonText = "View";
    if (label.trim().contains(' ')) {
      buttonText = "View " + label.trim().split(' ').last;
    } else {
      buttonText = "View $label";
    }

    return Padding(
      padding: EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label :',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.image),
            label: Text(buttonText),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF0E5C36),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
            onPressed: () => showImageDialog(context, label, url),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF0F4F5),
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: Color(0xFFF0F4F5),
        elevation: 0,
        foregroundColor: Colors.black,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Color(0xFFF0F4F5),
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        title: RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            children: [
              TextSpan(
                text: 'Fundra',
                style: TextStyle(color: Color(0xFF0E5C36)),
              ),
              TextSpan(text: 'IN', style: TextStyle(color: Color(0xFFE67D13))),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detail Data Pengajuan',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),

            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              margin: EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Agent",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          "Nama: ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "${orderData['agentName'] ?? '-'}",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Text("E-mail: ${orderData['agentEmail'] ?? '-'}"),
                    GestureDetector(
                      onTap: () async {
                        final phone = orderData['agentPhone'] ?? '';
                        if (phone.isNotEmpty) {
                          final url =
                              'https://wa.me/${normalizePhoneNumber(phone)}';
                          if (await canLaunch(url)) {
                            await launch(url);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Tidak dapat membuka WhatsApp'),
                              ),
                            );
                          }
                        }
                      },
                      child: Text(
                        "No. Telp: ${orderData['agentPhone'] ?? '-'}",
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                    SizedBox(height: 16),

                    Text(
                      "Pengaju",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          "Nama: ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "${orderData['name'] ?? '-'}",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () async {
                        final phone = orderData['phone'] ?? '';
                        if (phone.isNotEmpty) {
                          final url =
                              'https://wa.me/${normalizePhoneNumber(phone)}';
                          if (await canLaunch(url)) {
                            await launch(url);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Tidak dapat membuka WhatsApp'),
                              ),
                            );
                          }
                        }
                      },
                      child: Text(
                        "No. Telp: ${orderData['phone'] ?? '-'}",
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                    Text("E-mail: ${orderData['email'] ?? '-'}"),
                    Text("Alamat: ${orderData['domicile'] ?? '-'}"),
                    Text("Kode Pos: ${orderData['postalCode'] ?? '-'}"),
                    Text("Pekerjaan: ${orderData['job'] ?? '-'}"),
                    Text("Pendapatan: ${orderData['income'] ?? '-'}"),
                    Text("Pengajuan: ${orderData['item'] ?? '-'}"),
                    Text("Angsuran Lain: ${orderData['installment'] ?? '-'}"),

                    SizedBox(height: 16),
                    if (orderData['ktp'] != null)
                      buildImageRow(context, "Foto KTP", orderData['ktp']),

                    if (orderData['kk'] != null)
                      buildImageRow(context, "Foto KK", orderData['kk']),

                    if (orderData['slipgaji'] != null)
                      buildImageRow(
                        context,
                        "Slip Gaji",
                        orderData['slipgaji'],
                      ),

                    if (orderData['npwp'] != null)
                      buildImageRow(context, "NPWP", orderData['npwp']),

                    if ((orderData['item'] ?? '')
                        .toString()
                        .toLowerCase()
                        .contains('amanah')) ...[
                      if (orderData['stnk'] != null)
                        buildImageRow(context, "STNK", orderData['stnk']),
                      if (orderData['bpkb'] != null)
                        buildImageRow(context, "BPKB", orderData['bpkb']),
                    ],

                    SizedBox(height: 16),
                    Text(
                      "Tanggal Pengajuan: ${formatTimestamp(orderData['timestamp'])}",
                    ),

                    ..._buildStatusTimestamps(orderData),

                    SizedBox(height: 16),
                    Text(
                      "Status: ${orderData['status'] ?? '-'}",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStatusTimestamps(Map orderData) {
    final statusTimestamps = {
      'process': 'Tanggal Process',
      'approved': 'Tanggal Disetujui',
      'rejected': 'Tanggal Ditolak',
      'canceled': 'Tanggal Dibatalkan',
      'pending': 'Tanggal Pending',
    };

    List<Widget> widgets = [];

    statusTimestamps.forEach((key, label) {
      final timestampKey = '${key}Timestamp';
      if (orderData['status'] == key) {
        final timestamp = orderData[timestampKey] ?? orderData['timestamp'];
        widgets.add(Text("$label: ${formatTimestamp(timestamp)}"));
      }
    });

    return widgets;
  }

  String formatTimestamp(dynamic ts) {
    if (ts is int) {
      final date = DateTime.fromMillisecondsSinceEpoch(ts);
      return "${date.day}-${date.month}-${date.year}";
    }
    return ts.toString();
  }

  String normalizePhoneNumber(String phone) {
    if (phone.startsWith('0')) {
      return '62${phone.substring(1)}';
    }
    return phone;
  }
}
