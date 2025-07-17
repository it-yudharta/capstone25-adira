class NotificationTemplate {
  final String id;
  final String message;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  NotificationTemplate({
    required this.id,
    required this.message,
    this.createdAt,
    this.updatedAt,
  });

  factory NotificationTemplate.fromMap(String id, Map<String, dynamic> data) {
    return NotificationTemplate(
      id: id,
      message: data['message'] ?? '',
      createdAt: data['createdAt']?.toDate(),
      updatedAt: data['updatedAt']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'updatedAt': DateTime.now(),
    };
  }

  NotificationTemplate copyWith({
    String? id,
    String? message,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationTemplate(
      id: id ?? this.id,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Enum untuk jenis template notifikasi
enum NotificationTemplateType {
  agenStatusDefault('agen_status_default', 'Status Default'),
  agenStatusDibatalkan('agen_status_dibatalkan', 'Status Dibatalkan'),
  agenStatusDiproses('agen_status_diproses', 'Status Diproses'),
  agenStatusDiterima('agen_status_diterima', 'Status Diterima'),
  agenStatusDitolak('agen_status_ditolak', 'Status Ditolak'),
  agentAdded('agent_added', 'Agent Ditambahkan'),
  agentStatusDibatalkan('agent_status_dibatalkan', 'Agent Status Dibatalkan'),
  agentStatusDiterima('agent_status_diterima', 'Agent Status Diterima'),
  agentStatusDitolak('agent_status_ditolak', 'Agent Status Ditolak'),
  orderAdded('order_added', 'Order Ditambahkan'),
  orderStatusDibatalkan('order_status_dibatalkan', 'Order Status Dibatalkan'),
  orderStatusDiproses('order_status_diproses', 'Order Status Diproses'),
  orderStatusDiterima('order_status_diterima', 'Order Status Diterima'),
  orderStatusDitolak('order_status_ditolak', 'Order Status Ditolak');

  const NotificationTemplateType(this.id, this.displayName);

  final String id;
  final String displayName;

  static NotificationTemplateType? fromId(String id) {
    for (NotificationTemplateType type in NotificationTemplateType.values) {
      if (type.id == id) {
        return type;
      }
    }
    return null;
  }
}

