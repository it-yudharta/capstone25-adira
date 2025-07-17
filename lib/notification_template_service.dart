import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_template.dart';

class NotificationTemplateService {
  static const String _collection = 'templates';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all notification templates
  Future<List<NotificationTemplate>> getAllTemplates() async {
    try {
      QuerySnapshot querySnapshot = await _firestore.collection(_collection).get();

      return querySnapshot.docs.map((doc) {
        return NotificationTemplate.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get templates: $e');
    }
  }

  // Get templates by role
  Future<List<NotificationTemplate>> getTemplatesByRole(String role) async {
  try {
    final allTemplates = await getAllTemplates();

    return allTemplates.where((template) {
      if (role == 'pendaftaran') {
        return template.id.startsWith('agen_status_') || template.id == 'agent_added';
      } else if (role == 'pengajuan') {
        return template.id.startsWith('agent_status_') || template.id.startsWith('order_');
      }
      return false;
    }).toList();
  } catch (e) {
    throw Exception('Failed to filter templates by role: $e');
  }
}


  // Get specific template by ID
  Future<NotificationTemplate?> getTemplate(String templateId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection(_collection).doc(templateId).get();

      if (doc.exists) {
        return NotificationTemplate.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get template: $e');
    }
  }

  // Update template message
  Future<void> updateTemplate(String templateId, String message) async {
    try {
      await _firestore.collection(_collection).doc(templateId).update({
        'message': message,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update template: $e');
    }
  }

  // Create new template (if needed)
  Future<void> createTemplate(String templateId, String message) async {
    try {
      await _firestore.collection(_collection).doc(templateId).set({
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to create template: $e');
    }
  }

  // Optional: Use Firestore prefix filtering (only if template IDs are grouped well lexicographically)
  Future<List<NotificationTemplate>> getTemplatesByCategory(String category) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection(_collection)
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: category)
          .where(FieldPath.documentId, isLessThan: category + 'z')
          .get();

      return querySnapshot.docs.map((doc) {
        return NotificationTemplate.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get templates by category: $e');
    }
  }

  // Stream for real-time updates
  Stream<List<NotificationTemplate>> getTemplatesStream() {
    return _firestore.collection(_collection).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return NotificationTemplate.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  // Get template stream by ID
  Stream<NotificationTemplate?> getTemplateStream(String templateId) {
    return _firestore.collection(_collection).doc(templateId).snapshots().map((doc) {
      if (doc.exists) {
        return NotificationTemplate.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }
      return null;
    });
  }
}
