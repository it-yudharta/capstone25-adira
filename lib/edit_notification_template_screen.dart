import 'package:flutter/material.dart';
import 'notification_template.dart';
import 'notification_template_service.dart';
import 'whatsapp_preview.dart';
import 'package:flutter/services.dart';
import 'bottom_nav_bar_pendaftaran.dart';
import 'custom_bottom_nav_bar.dart';

class EditNotificationTemplateScreen extends StatefulWidget {
  final NotificationTemplate template;
  final String?
  role; // Parameter role untuk menentukan jenis notifikasi (nullable)

  const EditNotificationTemplateScreen({
    Key? key,
    required this.template,
    this.role, // Tidak ada default value, akan ditentukan berdasarkan template ID
  }) : super(key: key);

  @override
  State<EditNotificationTemplateScreen> createState() =>
      _EditNotificationTemplateScreenState();
}

class _EditNotificationTemplateScreenState
    extends State<EditNotificationTemplateScreen> {
  final TextEditingController _messageController = TextEditingController();
  final NotificationTemplateService _templateService =
      NotificationTemplateService();
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _messageController.text = widget.template.message;
    _messageController.addListener(_onTextChanged);
    // Debugging: Print the initial message to check if it's empty
    print('Initial message from template: ${widget.template.message}');
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _hasChanges = _messageController.text != widget.template.message;
    });
  }

  // Method untuk menentukan role berdasarkan template ID jika tidak diberikan
  String _determineRole() {
    if (widget.role != null) {
      return widget.role!;
    }

    // Tentukan role berdasarkan template ID dengan logika yang lebih komprehensif
    final templateId = widget.template.id.toLowerCase();
    final templateMessage = widget.template.message.toLowerCase();

    // Cek berbagai kata kunci untuk pengajuan
    if (templateId.contains('pengajuan') ||
        templateId.contains('proposal') ||
        templateId.contains('submission') ||
        templateId.contains('customer') ||
        templateId.contains('client') ||
        templateId.contains('order_') ||
        templateMessage.contains('pengajuan') ||
        templateMessage.contains('proposal')) {
      return 'pengajuan';
    } else {
      return 'pendaftaran';
    }
  }

  // Method untuk menentukan teks header berdasarkan role dan template ID
  String _getHeaderText() {
    final statusText = _getStatusText(widget.template.id);
    final role = _determineRole();

    if (role == 'pengajuan') {
      return 'Bot Notifikasi Pengajuan $statusText';
    } else {
      return 'Bot Notifikasi Pendaftaran $statusText';
    }
  }

  // Method untuk menentukan teks subtitle berdasarkan role dan template ID
  String _getSubtitleText() {
    final role = _determineRole();
    final templateId = widget.template.id.toLowerCase();

    if (role == 'pendaftaran') {
      if (templateId.startsWith('agent_status_') ||
          templateId == 'agent_added' ||
          templateId.contains('agent_') ||
          templateId.contains('pendaftaran_')) {
        return 'Edit notifikasi untuk agent';
      } else {
        return 'Edit notifikasi untuk pendaftaran';
      }
    } else if (role == 'pengajuan') {
      if (templateId.startsWith('agent_status_')) {
        return 'Edit notifikasi untuk pengajuan untuk agent';
      } else if (templateId.startsWith('order_')) {
        return 'Edit notifikasi untuk customer';
      } else {
        return 'Edit notifikasi untuk pengajuan';
      }
    }

    return ''; // Default empty string if no match
  }

  @override
  Widget build(BuildContext context) {
    final role = _determineRole();

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
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
              color: Colors.black,
            ),
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
          ],
        ),
      ),
      body: SingleChildScrollView(
        // Wrap the Column with SingleChildScrollView
        child: Column(
          children: [
            // Header with template type - dengan subtitle dinamis
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _getTemplateColor(widget.template.id),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getTemplateIcon(widget.template.id),
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getHeaderText(), // Menggunakan header text yang dinamis
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2E2E2E),
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Subtitle dinamis
                            Text(
                              _getSubtitleText().isNotEmpty
                                  ? _getSubtitleText()
                                  : 'Edit notifikasi',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Live Preview Section - ukuran diperkecil
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Live Preview',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E2E2E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Lihat bagaimana notifikasi akan terlihat di WhatsApp',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),

                  // WhatsApp Preview Widget
                  SimpleWhatsAppPreview(
                    title:
                        _getHeaderText(), // Menggunakan header text yang dinamis
                    message: _messageController.text,
                    templateId: widget.template.id,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Message editing area - diperbesar lebih banyak, tanpa teks deskripsi
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Message input field - diperbaiki: hapus minLines ketika expands true
                  SizedBox(
                    height:
                        200, // Set a fixed height for the TextField to avoid overflow in column
                    child: TextField(
                      controller: _messageController,
                      maxLines: null,
                      expands:
                          true, // Ketika expands true, tidak boleh ada minLines
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(fontSize: 16, height: 1.5),
                      decoration: InputDecoration(
                        hintText: 'Masukkan pesan notifikasi...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFE0E0E0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF0E5C36),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                        filled: true,
                        fillColor: const Color(0xFFFAFAFA),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Helper text for placeholders - tanpa company dan amount
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Placeholder yang tersedia:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF666666),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '{{name}} - Nama pengguna\n{{status}} - Status pendaftaran\n{{date}} - Tanggal\n{{id}} - ID transaksi',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .spaceEvenly, // Added for better button distribution
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => _onBackPressed(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Color(0xFF0E5C36)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF0E5C36),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _isLoading || !_hasChanges
                              ? null
                              : _showConfirmSaveDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0E5C36),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        disabledBackgroundColor: Colors.grey,
                      ),
                      child:
                          _isLoading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text(
                                'Confirm',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          role == 'pengajuan'
              ? const CustomBottomNavBar(currentRoute: 'other')
              : BottomNavBarPendaftaran(currentRoute: 'status'),
    );
  }

  Color _getTemplateColor(String templateId) {
    if (templateId.contains('diterima') || templateId.contains('approve')) {
      return const Color(0xFF0E5C36); // Green for approved
    } else if (templateId.contains('ditolak') ||
        templateId.contains('reject')) {
      return const Color(0xFFD32F2F); // Red for rejected
    } else if (templateId.contains('diproses') ||
        templateId.contains('process')) {
      return const Color(0xFFFF9800); // Orange for processing
    } else if (templateId.contains('dibatalkan')) {
      return const Color(0xFF757575); // Grey for cancelled
    } else {
      return const Color(0xFF1976D2); // Blue for default/incoming
    }
  }

  IconData _getTemplateIcon(String templateId) {
    if (templateId.contains('diterima') || templateId.contains('approve')) {
      return Icons.check_circle;
    } else if (templateId.contains('ditolak') ||
        templateId.contains('reject')) {
      return Icons.cancel;
    } else if (templateId.contains('diproses') ||
        templateId.contains('process')) {
      return Icons.hourglass_empty;
    } else if (templateId.contains('dibatalkan')) {
      return Icons.block;
    } else {
      return Icons.notifications;
    }
  }

  String _getStatusText(String templateId) {
    if (templateId.contains('diterima') || templateId.contains('approve')) {
      return 'Approve';
    } else if (templateId.contains('ditolak') ||
        templateId.contains('reject')) {
      return 'Reject';
    } else if (templateId.contains('diproses') ||
        templateId.contains('process')) {
      return 'Process';
    } else if (templateId.contains('dibatalkan')) {
      return 'Cancelled';
    } else {
      return 'Incoming';
    }
  }

  Future<void> _saveTemplate() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pesan tidak boleh kosong')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _templateService.updateTemplate(
        widget.template.id,
        _messageController.text.trim(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Template berhasil diperbarui'),
          backgroundColor: Color(0xFF0E5C36),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onBackPressed() {
    if (_hasChanges) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Perubahan Belum Disimpan'),
              content: const Text(
                'Anda memiliki perubahan yang belum disimpan. Apakah Anda yakin ingin keluar?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Close screen
                  },
                  child: const Text('Keluar'),
                ),
              ],
            ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _showConfirmSaveDialog() {
    final role = _determineRole();
    final statusText = _getStatusText(widget.template.id);

    String dialogTitle = 'Edit Notif Bot?';
    String dialogContent = 'Notif Bot message for ';

    if (role == 'pengajuan') {
      dialogContent += 'pengajuan ';
    } else {
      dialogContent += 'pendaftaran ';
    }

    if (statusText == 'Approve') {
      dialogContent += 'approved ';
    } else if (statusText == 'Reject') {
      dialogContent += 'rejected ';
    } else if (statusText == 'Process') {
      dialogContent += 'process ';
    } else if (statusText == 'Incoming') {
      dialogContent += 'incoming ';
    } else if (statusText == 'Cancelled') {
      dialogContent += 'cancelled ';
    }
    dialogContent += 'will be changed.';

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
                boxShadow: const [
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
                    dialogTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    dialogContent,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFE67D13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Back',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _saveTemplate();
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFF0E5C36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
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
}
