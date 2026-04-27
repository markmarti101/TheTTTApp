import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/document.dart';

class DocumentService {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  /// Launches the file picker, uploads the selected file to Firebase Storage,
  /// and saves metadata to the `documents` Firestore collection.
  /// Returns null if the user cancelled or if the upload failed.
  Future<CourseDocument?> pickAndUpload({
    required String courseId,
    required String courseNumber,
    required String trainingCompanyId,
    required String clientId,
    required String uploadedBy,
    required String uploaderRole,
    required String type,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final storagePath =
        'documents/$trainingCompanyId/$courseId/$type/$fileName';
    final ref = _storage.ref().child(storagePath);

    late UploadTask task;
    if (file.path != null) {
      task = ref.putFile(File(file.path!));
    } else if (file.bytes != null) {
      task = ref.putData(file.bytes!);
    } else {
      return null;
    }

    final snapshot = await task;
    final downloadUrl = await snapshot.ref.getDownloadURL();
    final now = DateTime.now().toUtc().toIso8601String();

    final docRef = await _firestore.collection('documents').add({
      'courseId': courseId,
      'courseNumber': courseNumber,
      'trainingCompanyId': trainingCompanyId,
      'clientId': clientId,
      'uploadedBy': uploadedBy,
      'uploaderRole': uploaderRole,
      'type': type,
      'fileName': file.name,
      'downloadUrl': downloadUrl,
      'storagePath': storagePath,
      'createdAt': now,
    });

    return CourseDocument(
      id: docRef.id,
      courseId: courseId,
      courseNumber: courseNumber,
      trainingCompanyId: trainingCompanyId,
      clientId: clientId,
      uploadedBy: uploadedBy,
      uploaderRole: uploaderRole,
      type: type,
      fileName: file.name,
      downloadUrl: downloadUrl,
      storagePath: storagePath,
      createdAt: now,
    );
  }

  Future<List<CourseDocument>> getDocumentsByCourse(
    String courseId, {
    String? clientId,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('documents')
        .where('courseId', isEqualTo: courseId);
    if (clientId != null && clientId.isNotEmpty) {
      query = query.where('clientId', isEqualTo: clientId);
    }
    final snap = await query.get();
    return snap.docs
        .map((d) => CourseDocument.fromFirestore(d.id, d.data()))
        .toList();
  }

  Future<void> deleteDocument(CourseDocument doc) async {
    try {
      if (doc.storagePath.isNotEmpty) {
        await _storage.ref().child(doc.storagePath).delete();
      }
    } catch (_) {}
    await _firestore.collection('documents').doc(doc.id).delete();
  }
}
