import 'package:cloud_firestore/cloud_firestore.dart';

enum VaultSection { personal, business }

class AppProfile {
  final String id;
  final String userId;
  final VaultSection section;
  final String name;
  final String? label;
  final List<String> categories;

  AppProfile({
    required this.id,
    required this.userId,
    required this.section,
    required this.name,
    this.label,
    List<String>? categories,
  }) : categories = categories ?? (section == VaultSection.business 
            ? ['Legal', 'Financial', 'Bills', 'Staffing']
            : ['Medical', 'Legal', 'Financial', 'Personal']);

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'section': section.name,
      'name': name,
      'label': label,
      'categories': categories,
    };
  }

  factory AppProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final section = VaultSection.values.byName(data['section']);
    return AppProfile(
      id: doc.id,
      userId: data['userId'],
      section: section,
      name: data['name'],
      label: data['label'],
      categories: data['categories'] != null 
          ? List<String>.from(data['categories']) 
          : (section == VaultSection.business 
              ? ['Legal', 'Financial', 'Bills', 'Staffing']
              : ['Medical', 'Legal', 'Financial', 'Personal']),
    );
  }
}

class AppDocument {
  final String id;
  final String profileId;
  final String fileUrl;
  final String fileType; // image, pdf
  final String category;
  final String fileName;
  final DateTime createdAt;
  final DateTime? expiryDate;
  final bool isStarred;

  AppDocument({
    required this.id,
    required this.profileId,
    required this.fileUrl,
    required this.fileType,
    required this.category,
    required this.fileName,
    required this.createdAt,
    this.expiryDate,
    this.isStarred = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'profileId': profileId,
      'fileUrl': fileUrl,
      'fileType': fileType,
      'category': category,
      'fileName': fileName,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'isStarred': isStarred,
    };
  }

  factory AppDocument.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppDocument(
      id: doc.id,
      profileId: data['profileId'],
      fileUrl: data['fileUrl'],
      fileType: data['fileType'],
      category: data['category'],
      fileName: data['fileName'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiryDate: data['expiryDate'] != null 
          ? (data['expiryDate'] as Timestamp).toDate() 
          : null,
      isStarred: data['isStarred'] ?? false,
    );
  }
}
