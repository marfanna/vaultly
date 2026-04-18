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
  }) : categories = categories ??
            (section == VaultSection.business
                ? ['Legal', 'Financial', 'Bills', 'Staffing']
                : ['Medical', 'Legal', 'Financial', 'Personal', 'Education']);

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
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final sectionName = data['section'] as String? ?? VaultSection.personal.name;
    final section = VaultSection.values.firstWhere(
      (v) => v.name == sectionName,
      orElse: () => VaultSection.personal,
    );
    return AppProfile(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      section: section,
      name: data['name'] as String? ?? '',
      label: data['label'] as String?,
      categories: data['categories'] != null
          ? List<String>.from(data['categories'] as List)
          : null,
    );
  }
}

class AppDocument {
  final String id;
  final String userId;
  final String profileId;
  final String fileUrl;
  final String fileType;
  final String category;
  final String fileName;
  final DateTime createdAt;
  final DateTime? expiryDate;
  final bool isStarred;

  AppDocument({
    required this.id,
    required this.userId,
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
      'userId': userId,
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
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppDocument(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      profileId: data['profileId'] as String? ?? '',
      fileUrl: data['fileUrl'] as String? ?? '',
      fileType: data['fileType'] as String? ?? 'image',
      category: data['category'] as String? ?? 'Personal',
      fileName: data['fileName'] as String? ?? doc.id,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiryDate: (data['expiryDate'] as Timestamp?)?.toDate(),
      isStarred: data['isStarred'] as bool? ?? false,
    );
  }
}
