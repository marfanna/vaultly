import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as img;
import 'models.dart';

class FirebaseService {
  static final _firestore = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get currentUid => _auth.currentUser?.uid;

  // --- Helpers ---

  static String sanitizePath(String segment) {
    final lastDot = segment.lastIndexOf('.');
    final hasExt = lastDot > 0 && lastDot < segment.length - 1;

    if (hasExt) {
      final base = segment
          .substring(0, lastDot)
          .replaceAll(RegExp(r'[^\w-]'), '_');
      final ext = segment
          .substring(lastDot + 1)
          .replaceAll(RegExp(r'[^\w]'), '');
      return '$base.$ext';
    }
    return segment.replaceAll(RegExp(r'[^\w-]'), '_');
  }

  static Future<File> compressImage(File file) async {
    final imageBytes = await file.readAsBytes();
    final image = img.decodeImage(imageBytes);
    if (image == null) return file;

    img.Image resized;
    if (image.width > 1080 || image.height > 1080) {
      resized = image.width > image.height
          ? img.copyResize(image, width: 1080)
          : img.copyResize(image, height: 1080);
    } else {
      resized = image;
    }

    final compressedBytes = img.encodeJpg(resized, quality: 80);
    final compressedFile = File('${file.path}_compressed.jpg');
    await compressedFile.writeAsBytes(compressedBytes);
    return compressedFile;
  }

  // --- Profiles ---

  static Stream<List<AppProfile>> streamProfiles(VaultSection section) {
    final uid = currentUid;
    if (uid == null) return const Stream.empty();

    return _firestore
        .collection('profiles')
        .where('section', isEqualTo: section.name)
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => AppProfile.fromFirestore(doc)).toList());
  }

  static Future<void> createProfile(AppProfile profile) async {
    final uid = currentUid;
    if (uid == null) throw Exception('User not authenticated');

    final profileData = profile.toMap();
    profileData['userId'] = uid;

    await _firestore.collection('profiles').add(profileData);
  }

  static Future<void> updateProfile(AppProfile profile) async {
    final uid = currentUid;
    if (uid == null) throw Exception('User not authenticated');
    if (profile.userId != uid) throw Exception('Access denied');

    await _firestore
        .collection('profiles')
        .doc(profile.id)
        .update(profile.toMap());
  }

  static Future<void> deleteProfile(String profileId) async {
    final uid = currentUid;
    if (uid == null) throw Exception('User not authenticated');

    final profileDoc =
        await _firestore.collection('profiles').doc(profileId).get();
    if (!profileDoc.exists || profileDoc.data()?['userId'] != uid) {
      throw Exception('Access denied');
    }

    final docs = await _firestore
        .collection('documents')
        .where('profileId', isEqualTo: profileId)
        .get();
    for (var doc in docs.docs) {
      await doc.reference.delete();
    }
    await _firestore.collection('profiles').doc(profileId).delete();
  }

  static Future<void> addCategory(String profileId, String category) async {
    await _firestore.collection('profiles').doc(profileId).update({
      'categories': FieldValue.arrayUnion([category])
    });
  }

  static Future<void> removeCategory(
      String profileId, String category) async {
    await _firestore.collection('profiles').doc(profileId).update({
      'categories': FieldValue.arrayRemove([category])
    });
  }

  // --- Documents ---

  static Future<String> uploadFile(File file, String path) async {
    if (!await file.exists()) {
      throw Exception('Source file not found locally.');
    }

    File uploadFile = file;
    final lowerPath = path.toLowerCase();
    final isImage = lowerPath.endsWith('.jpg') ||
        lowerPath.endsWith('.jpeg') ||
        lowerPath.endsWith('.png');

    try {
      if (isImage) {
        uploadFile = await compressImage(file);
      }

      final ref = _storage.ref().child(path);
      final taskSnapshot = await ref.putFile(uploadFile);
      return await taskSnapshot.ref.getDownloadURL();
    } on FirebaseException {
      rethrow;
    } finally {
      if (isImage && uploadFile.path != file.path) {
        await uploadFile.delete().catchError((_) => uploadFile);
      }
    }
  }

  static Future<void> saveDocument(AppDocument doc) async {
    await _firestore.collection('documents').add(doc.toMap());
  }

  static Stream<List<AppDocument>> streamDocuments(
    String profileId, {
    String? category,
    bool starredOnly = false,
    int? limit,
  }) {
    final uid = currentUid;
    if (uid == null) return const Stream.empty();

    var query = _firestore
        .collection('documents')
        .where('profileId', isEqualTo: profileId)
        .where('userId', isEqualTo: uid);

    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }
    if (starredOnly) {
      query = query.where('isStarred', isEqualTo: true);
    }

    query = query.orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => AppDocument.fromFirestore(doc)).toList());
  }

  static Stream<List<AppDocument>> streamExpiringDocuments() {
    final uid = currentUid;
    if (uid == null) return const Stream.empty();

    final now = DateTime.now();
    final cutoff = now.add(const Duration(days: 90));

    return _firestore
        .collection('documents')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((s) {
          final docs = s.docs.map((d) => AppDocument.fromFirestore(d)).toList();
          return docs
              .where((d) =>
                  d.expiryDate != null &&
                  !d.expiryDate!.isBefore(now.subtract(const Duration(days: 1))) &&
                  d.expiryDate!.isBefore(cutoff))
              .toList()
            ..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));
        });
  }

  static Stream<Map<String, int>> streamAllCategoryCounts(String profileId) {
    final uid = currentUid;
    if (uid == null) return const Stream.empty();

    return _firestore
        .collection('documents')
        .where('profileId', isEqualTo: profileId)
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      final counts = <String, int>{};
      for (var doc in snapshot.docs) {
        final cat = doc.data()['category'] as String? ?? 'General';
        counts[cat] = (counts[cat] ?? 0) + 1;
      }
      return counts;
    });
  }

  static Future<int> getDocumentCount(
      String profileId, String category) async {
    final uid = currentUid;
    if (uid == null) return 0;

    try {
      final snapshot = await _firestore
          .collection('documents')
          .where('profileId', isEqualTo: profileId)
          .where('userId', isEqualTo: uid)
          .where('category', isEqualTo: category)
          .count()
          .get()
          .timeout(const Duration(seconds: 3));
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  static Future<void> deleteDocument(AppDocument doc) async {
    final uid = currentUid;
    if (uid == null) throw Exception('User not authenticated');
    if (doc.userId != uid) throw Exception('Access denied');

    await _firestore.collection('documents').doc(doc.id).delete();

    try {
      final ref = _storage.refFromURL(doc.fileUrl);
      await ref.delete();
    } on FirebaseException {
      // Storage delete is best-effort; Firestore record is already removed.
    }
  }

  static Future<void> toggleDocumentStar(AppDocument doc) async {
    final uid = currentUid;
    if (uid == null) throw Exception('User not authenticated');
    if (doc.userId != uid) throw Exception('Access denied');

    await _firestore.collection('documents').doc(doc.id).update({
      'isStarred': !doc.isStarred,
    });
  }
}
