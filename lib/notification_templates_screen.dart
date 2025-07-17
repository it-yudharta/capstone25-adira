import 'package:flutter/material.dart';
import 'notification_template.dart';
import 'notification_template_service.dart';
import 'edit_notification_template_screen.dart';
import 'package:flutter/services.dart';
import 'custom_bottom_nav_bar.dart';
import 'bottom_nav_bar_pendaftaran.dart';

class NotificationTemplatesScreen extends StatefulWidget {
  final String role; // 'pendaftaran' atau 'pengajuan'

  const NotificationTemplatesScreen({Key? key, required this.role})
    : super(key: key);

  @override
  State<NotificationTemplatesScreen> createState() =>
      _NotificationTemplatesScreenState();
}

class _NotificationTemplatesScreenState
    extends State<NotificationTemplatesScreen> {
  final NotificationTemplateService _templateService =
      NotificationTemplateService();
  List<NotificationTemplate> _templates = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      setState(() => _isLoading = true);
      final templates = await _templateService.getTemplatesByRole(widget.role);
      setState(() {
        _templates = templates;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading templates: $e')));
    }
  }

  String _getTemplateStatus(String templateId) {
    if (templateId.contains("diterima") || templateId.contains("approve")) {
      return "approve";
    } else if (templateId.contains("ditolak") ||
        templateId.contains("reject")) {
      return "reject";
    } else if (templateId.contains("diproses") ||
        templateId.contains("process")) {
      return "process";
    } else if (templateId.contains("dibatalkan") ||
        templateId.contains("cancel")) {
      return "cancel";
    } else if (templateId.contains("incoming") ||
        templateId.contains("added")) {
      return "incoming";
    } else {
      return "other";
    }
  }

  List<NotificationTemplate> get _filteredTemplates {
    List<NotificationTemplate> filtered =
        _templates.where((template) {
          final type = NotificationTemplateType.fromId(template.id);
          return template.id.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              (type?.displayName.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ??
                  false);
        }).toList();

    if (widget.role == 'pengajuan') {
      // Define the desired order of statuses
      final List<String> statusOrder = [
        'approve',
        'reject',
        'process',
        'cancel',
        'incoming',
      ];

      // Group templates by status
      Map<String, List<NotificationTemplate>> groupedTemplates = {};
      for (var status in statusOrder) {
        groupedTemplates[status] = [];
      }

      for (var template in filtered) {
        String status = _getTemplateStatus(template.id);
        if (groupedTemplates.containsKey(status)) {
          groupedTemplates[status]!.add(template);
        } else {
          // Handle other statuses not explicitly defined in statusOrder
          // For now, we can add them to a generic 'other' category or ignore
          // For this task, we'll ignore them if not in the defined order
        }
      }

      // Flatten the grouped templates into a single list in the desired order
      List<NotificationTemplate> sortedTemplates = [];
      for (var status in statusOrder) {
        sortedTemplates.addAll(groupedTemplates[status]!);
      }
      return sortedTemplates;
    } else {
      return filtered;
    }
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 10.0,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: 12.0,
                horizontal: 16.0,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                widget.role == 'pendaftaran'
                    ? 'Bot Notifikasi Pendaftaran'
                    : 'Bot Notifikasi Pengajuan',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          // Templates List
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF0E5C36),
                      ),
                    )
                    : _filteredTemplates.isEmpty
                    ? const Center(
                      child: Text(
                        'Tidak ada template ditemukan',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _loadTemplates,
                      color: const Color(0xFF0E5C36),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredTemplates.length,
                        itemBuilder: (context, index) {
                          final template = _filteredTemplates[index];
                          final type = NotificationTemplateType.fromId(
                            template.id,
                          );

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 0,
                            ),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            color: const Color(0xFF0E5C36),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 16,
                              ),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _getTemplateIcon(template.id),
                                  color: _getTemplateColor(template.id),
                                  size: 24,
                                ),
                              ),
                              title: Text(
                                type?.displayName ?? template.id,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                              subtitle: Text(
                                (widget.role == 'pendaftaran' &&
                                        (template.id.startsWith(
                                              "agen_status_",
                                            ) ||
                                            template.id == "agent_added"))
                                    ? "Edit notifikasi untuk agent"
                                    : (widget.role == 'pengajuan' &&
                                        template.id.startsWith("agent_status_"))
                                    ? "Edit notifikasi untuk pengajuan untuk agent"
                                    : (widget.role == 'pengajuan' &&
                                        template.id.startsWith("order_"))
                                    ? "Edit notifikasi untuk customer"
                                    : "",
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                color: Color(0xFF0E5C36),
                                size: 16,
                              ),
                              onTap: () => _editTemplate(template),
                            ),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
      bottomNavigationBar:
          widget.role == 'pengajuan'
              ? CustomBottomNavBar(currentRoute: 'notifikasi')
              : BottomNavBarPendaftaran(currentRoute: 'notifikasi'),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _editTemplate(NotificationTemplate template) {
    final isPendaftaranTemplate =
        template.id.startsWith('agen_status_') || template.id == 'agent_added';

    final isPengajuanTemplate =
        template.id.startsWith('agent_status_') ||
        template.id.startsWith('order_');

    final allowed =
        (widget.role == 'pendaftaran' && isPendaftaranTemplate) ||
        (widget.role == 'pengajuan' && isPengajuanTemplate);

    if (!allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Anda tidak memiliki akses untuk mengedit template ini',
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => EditNotificationTemplateScreen(template: template),
      ),
    ).then((_) => _loadTemplates());
  }
}
