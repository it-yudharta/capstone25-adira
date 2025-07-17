import 'package:flutter/material.dart';

class SimpleWhatsAppPreview extends StatelessWidget {
  final String title;
  final String message;
  final String templateId;

  const SimpleWhatsAppPreview({
    Key? key,
    required this.title,
    required this.message,
    required this.templateId,
  }) : super(key: key);

  // Method untuk mengganti placeholder dengan contoh data (tanpa company dan amount)
  String _replacePlaceholders(String text) {
    return text
        .replaceAll('{{name}}', 'John Doe')
        .replaceAll('{{status}}', 'Approved')
        .replaceAll('{{date}}', '15 Januari 2025')
        .replaceAll('{{time}}', '14:30')
        .replaceAll('{{phone}}', '+62 812-3456-7890')
        .replaceAll('{{email}}', 'john.doe@email.com')
        .replaceAll('{{id}}', 'FDR001234')
        .replaceAll('{{type}}', 'Premium Account');
  }

  @override
  Widget build(BuildContext context) {
    final processedMessage = _replacePlaceholders(message.isNotEmpty ? message : 'This is a message sent by the business. You can customise it to with a ton of variants!');
    
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 200), // Batasi tinggi preview
      decoration: BoxDecoration(
        color: const Color(0xFF111B21), // WhatsApp dark background
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // WhatsApp header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF202C33), // WhatsApp header color
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                // Back arrow
                Icon(Icons.arrow_back, color: Colors.white70, size: 18),
                const SizedBox(width: 10),
                
                // Business avatar
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _getTemplateColor(templateId),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _getTemplateIcon(templateId),
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 10),
                
                // Business name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
                      Text(
                        'online',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Menu icons
                Icon(Icons.more_vert, color: Colors.white70, size: 18),
              ],
            ),
          ),

          // Chat area background
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFF0B141A), // WhatsApp chat background
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Business avatar
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _getTemplateColor(templateId),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _getTemplateIcon(templateId),
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Message bubble
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF202C33), // WhatsApp incoming message color
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(14),
                          bottomLeft: Radius.circular(14),
                          bottomRight: Radius.circular(14),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Business name
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0E5C36), // Business name color
                            ),
                          ),
                          const SizedBox(height: 4),
                          
                          // Message content with replaced placeholders
                          Text(
                            processedMessage,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFE9EDEF), // WhatsApp text color
                              height: 1.3,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          
                          const SizedBox(height: 6),
                          
                          // Timestamp
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '9:41',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTemplateColor(String templateId) {
    if (templateId.contains('diterima') || templateId.contains('approve')) {
      return const Color(0xFF0E5C36); // Green for approved
    } else if (templateId.contains('ditolak') || templateId.contains('reject')) {
      return const Color(0xFFD32F2F); // Red for rejected
    } else if (templateId.contains('diproses') || templateId.contains('process')) {
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
    } else if (templateId.contains('ditolak') || templateId.contains('reject')) {
      return Icons.cancel;
    } else if (templateId.contains('diproses') || templateId.contains('process')) {
      return Icons.hourglass_empty;
    } else if (templateId.contains('dibatalkan')) {
      return Icons.block;
    } else {
      return Icons.notifications;
    }
  }
}

