import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PendaftaranDetailScreen extends StatelessWidget {
  final Map agentData;

  const PendaftaranDetailScreen({super.key, required this.agentData});

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
            label: Text("Lihat $label"),
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
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detail Data Pendaftaran',
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
                      "Pendaftar",
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
                          "${agentData['fullName'] ?? '-'}",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Text("E-mail: ${agentData['email'] ?? '-'}"),
                    Text("No. Telp: ${agentData['phone'] ?? '-'}"),
                    Text("Alamat: ${agentData['address'] ?? '-'}"),
                    Text("Kode Pos: ${agentData['postalCode'] ?? '-'}"),

                    SizedBox(height: 16),
                    if (agentData['ktp'] != null)
                      buildImageRow(context, "Foto KTP", agentData['ktp']),
                    if (agentData['kk'] != null)
                      buildImageRow(context, "Foto KK", agentData['kk']),
                    if (agentData['npwp'] != null)
                      buildImageRow(context, "NPWP", agentData['npwp']),

                    SizedBox(height: 16),
                    Text("Tanggal Pendaftaran: ${agentData['tanggal'] ?? '-'}"),

                    SizedBox(height: 8),
                    Text(
                      "Status: ${agentData['status'] ?? '-'}",
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
}
