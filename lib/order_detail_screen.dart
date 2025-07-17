import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  Future<Map<String, dynamic>?> fetchHasilPrediksi(String orderKey) async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('hasil_prediksi')
              .doc(orderKey)
              .get();

      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      print("Error saat mengambil hasil prediksi: $e");
    }
    return null;
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
                    RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                        children: [
                          TextSpan(text: "No. Telp: "),
                          WidgetSpan(
                            child: GestureDetector(
                              onTap:
                                  () => _launchWhatsApp(
                                    context,
                                    orderData['agentPhone'] ?? '',
                                  ),
                              child: Text(
                                orderData['agentPhone'] ?? '-',
                                style: TextStyle(color: Colors.blue),
                              ),
                            ),
                          ),
                        ],
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
                    RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                        children: [
                          TextSpan(text: "No. Telp: "),
                          WidgetSpan(
                            child: GestureDetector(
                              onTap:
                                  () => _launchWhatsApp(
                                    context,
                                    orderData['phone'] ?? '',
                                  ),
                              child: Text(
                                orderData['phone'] ?? '-',
                                style: TextStyle(color: Colors.blue),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text("E-mail: ${orderData['email'] ?? '-'}"),
                    Text("Alamat: ${orderData['domicile'] ?? '-'}"),
                    Text("Kode Pos: ${orderData['postalCode'] ?? '-'}"),
                    Text("Pekerjaan: ${orderData['job'] ?? '-'}"),
                    Text("Pendapatan: ${orderData['income'] ?? '-'}"),
                    Text("Pengajuan: ${orderData['item'] ?? '-'}"),
                    if (!(orderData['item']?.toString().toLowerCase().contains(
                          'amanah',
                        ) ??
                        false))
                      Text("Merk: ${orderData['merk'] ?? '-'}"),
                    Text("Nominal: ${orderData['nominal'] ?? '-'}"),
                    Text("DP: ${orderData['dp'] ?? '-'}"),
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
                    Text("Tanggal Pengajuan: ${orderData['tanggal'] ?? '-'}"),
                    ..._buildStatusTimestamps(orderData),
                    SizedBox(height: 16),
                    Text(
                      "Status: ${orderData['status'] ?? '-'}",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (orderData['note'] != null &&
                        orderData['note'].toString().trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          "Note: ${orderData['note']}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    FutureBuilder<Map<String, dynamic>?>(
                      future: fetchHasilPrediksi(orderKey),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        } else if (snapshot.hasError) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Text('Gagal memuat hasil prediksi.'),
                          );
                        } else if (!snapshot.hasData) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Text('Belum ada hasil prediksi.'),
                          );
                        }

                        final hasil = snapshot.data!;
                        final status = hasil['status'] ?? '-';
                        final skorFuzzy = hasil['skor_fuzzy'] ?? '-';
                        final risiko = hasil['risiko'] ?? '-';
                        final alasanList = hasil['alasan'] as List? ?? [];
                        final saran = hasil['saran'];

                        return Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Hasil Evaluasi Pembiayaan",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text("Status: $status"),
                              Text("Skor Fuzzy: $skorFuzzy"),
                              Text("Risiko: $risiko"),
                              const SizedBox(height: 8),
                              if (alasanList.isNotEmpty) ...[
                                Text("Alasan:"),
                                ...alasanList.map((a) => Text("- $a")),
                              ],
                              if (saran != null &&
                                  saran.toString().trim().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text("Saran: $saran"),
                                ),
                            ],
                          ),
                        );
                      },
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
    final statusLabels = {
      'process': 'Tanggal Process',
      'cancel': 'Tanggal Cancel',
      'pending': 'Tanggal Pending',
      'approved': 'Tanggal Approve',
      'rejected': 'Tanggal Reject',
    };

    List<Widget> widgets = [];

    statusLabels.forEach((statusKey, label) {
      String tanggalStatus = '-';
      switch (statusKey) {
        case 'process':
          tanggalStatus = orderData['processUpdatedAt'] ?? '-';
          break;
        case 'approved':
          tanggalStatus = orderData['approveUpdatedAt'] ?? '-';
          break;
        case 'rejected':
          tanggalStatus = orderData['rejectUpdatedAt'] ?? '-';
          break;
        case 'cancel':
          tanggalStatus = orderData['cancelUpdatedAt'] ?? '-';
          break;
        case 'pending':
          tanggalStatus = orderData['pendingUpdatedAt'] ?? '-';
          break;
      }

      if (tanggalStatus != '-') {
        widgets.add(Text("$label: $tanggalStatus"));
      }
    });

    return widgets;
  }

  String formatTimestamp(dynamic ts) {
    if (ts == null) return '-';
    if (ts is int) {
      final date = DateTime.fromMillisecondsSinceEpoch(ts);
      return "${date.day}-${date.month}-${date.year}";
    }
    return ts.toString();
  }

  String normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) {
      return '62${digits.substring(1)}';
    } else if (digits.startsWith('62')) {
      return digits;
    } else {
      return '62$digits';
    }
  }

  Future<void> _launchWhatsApp(BuildContext context, String phone) async {
    final normalized = normalizePhone(phone);
    final uri = Uri.parse('https://wa.me/$normalized');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka WhatsApp')),
      );
    }
  }
}
