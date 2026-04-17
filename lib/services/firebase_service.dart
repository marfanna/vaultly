import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models.dart';

class FirebaseService {
  static final _firestore = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get currentUid => _auth.currentUser?.uid;

  // --- Helpers ---
  
  static String sanitizePath(String segment) {
    // Preserve the dot before the extension
    final ext = segment.contains('.') ? '.${segment.split('.').last}' : '';
    final base = segment.contains('.') 
        ? segment.substring(0, segment.lastIndexOf('.')) 
        : segment;
    return base.replaceAll(RegExp(r'[^\w-]'), '_') + ext;
  }

  // --- Profiles ---

  static Stream<List<AppProfile>> streamProfiles(VaultSection section) {
    final uid = currentUid;
    if (uid == null) return const Stream.empty();

    return _firestore
        .collection('profiles')
        .where('section', isEqualTo: section.name)
        .where('userId', isEqualTo: uid) // Secured by UID
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppProfile.fromFirestore(doc))
            .toList());
  }

  static Future<void> createProfile(AppProfile profile) async {
    final uid = currentUid;
    if (uid == null) throw Exception('User not authenticated');

    // Create a new profile map ensuring current UID is used
    final profileData = profile.toMap();
    profileData['userId'] = uid;

    await _firestore.collection('profiles').add(profileData);
  }

  static Future<void> updateProfile(AppProfile profile) async {
    await _firestore.collection('profiles').doc(profile.id).update(profile.toMap());
  }

  static Future<void> deleteProfile(String profileId) async {
    final docs = await _firestore.collection('documents').where('profileId', isEqualTo: profileId).get();
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

  // --- Documents ---

  static Future<String> uploadFile(File file, String path) async {
    try {
      if (!await file.exists()) {
        throw Exception('Source file not found locally.');
      }

      print('STORAGE: Bucket = ${_storage.bucket}');
      print('STORAGE: Full path = $path');
      
      final ref = _storage.ref().child(path);
      final taskSnapshot = await ref.putFile(file);
      
      return await taskSnapshot.ref.getDownloadURL();
      
    } on FirebaseException catch (e) {
      print('STORAGE ERROR [${e.code}]: ${e.message}');
      throw e;
    } catch (e) {
      print('STORAGE GENERIC ERROR: $e');
      rethrow;
    }
  }

  static Future<void> saveDocument(AppDocument doc) async {
    await _firestore.collection('documents').add(doc.toMap());
  }

  static Stream<List<AppDocument>> streamDocuments(String profileId, {String? category}) {
    var query = _firestore.collection('documents').where('profileId', isEqualTo: profileId);
    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }
    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => AppDocument.fromFirestore(doc))
        .toList());
  }

  static Stream<Map<String, int>> streamAllCategoryCounts(String profileId) {
    return _firestore
        .collection('documents')
        .where('profileId', isEqualTo: profileId)
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

  static Future<int> getDocumentCount(String profileId, String category) async {
    try {
      final snapshot = await _firestore
          .collection('documents')
          .where('profileId', isEqualTo: profileId)
          .where('category', isEqualTo: category)
          .count()
          .get()
          .timeout(const Duration(seconds: 3));
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
