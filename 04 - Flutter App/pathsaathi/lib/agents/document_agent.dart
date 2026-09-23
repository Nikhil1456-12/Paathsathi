import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureDocument {
  final String id;
  final String title;
  final String docType;
  final String maskedNumber;
  final String dateAdded;
  final String rawContent;

  /// Optional base64-encoded image bytes (for documents added as a photo).
  /// Stored inside the same encrypted vault — never leaves the device.
  final String? imageBase64;

  const SecureDocument({
    required this.id,
    required this.title,
    required this.docType,
    required this.maskedNumber,
    required this.dateAdded,
    required this.rawContent,
    this.imageBase64,
  });

  bool get hasImage => imageBase64 != null && imageBase64!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'docType': docType,
        'maskedNumber': maskedNumber,
        'dateAdded': dateAdded,
        'rawContent': rawContent,
        if (imageBase64 != null) 'imageBase64': imageBase64,
      };

  factory SecureDocument.fromJson(Map<String, dynamic> json) => SecureDocument(
        id: json['id'] as String,
        title: json['title'] as String,
        docType: json['docType'] as String,
        maskedNumber: json['maskedNumber'] as String,
        dateAdded: json['dateAdded'] as String,
        rawContent: json['rawContent'] as String,
        imageBase64: json['imageBase64'] as String?, // backward-compatible
      );

  /// Mask a raw ID number for display (keeps only the last 4 digits/chars).
  static String maskNumber(String raw) {
    final t = raw.replaceAll(RegExp(r'\s+'), '');
    if (t.length <= 4) return t;
    final last4 = t.substring(t.length - 4);
    return '${'X' * (t.length - 4)}$last4';
  }
}

class DocumentAgent {
  DocumentAgent._();
  static final DocumentAgent instance = DocumentAgent._();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  static const _docKey = 'pathsaathi_secure_docs_vault';
  static const _pinKey = 'pathsaathi_vault_pin';
  static const _imageChunkSize = 3500;
  static const _imageChunkPrefix = 'pathsaathi_secure_image_';

  Future<void> initializeDefaultDocs() async {
    final existing = await getDocuments();
    if (existing.isEmpty) {
      final defaultDocs = [
        const SecureDocument(
          id: 'doc_1',
          title: 'Identity Card (Aadhaar)',
          docType: 'Aadhaar Card',
          maskedNumber: 'XXXX-XXXX-1234',
          dateAdded: '28 Aug 2026',
          rawContent: 'Name: Pilgrim\nDOB: 15/08/1972\nUID: 9876 5432 1234',
        ),
        const SecureDocument(
          id: 'doc_2',
          title: 'Kumbh Mela Pilgrim Pass',
          docType: 'Official Pass',
          maskedNumber: 'PASS-KM-2026-908',
          dateAdded: '28 Aug 2026',
          rawContent:
              'Pass ID: KM-2026-908\nSector 7 Shakti Camp\nValid: 25 Aug - 10 Sep',
        ),
        const SecureDocument(
          id: 'doc_3',
          title: 'Special Train Ticket (PNR)',
          docType: 'Travel Ticket',
          maskedNumber: 'PNR: 4821XXXX',
          dateAdded: '29 Aug 2026',
          rawContent:
              'Train: 12417 Prayagraj Exp\nCoach: S4, Berth: 32\nFrom: Prayagraj to New Delhi',
        ),
      ];
      await saveDocuments(defaultDocs);
    }
  }

  Future<List<SecureDocument>> getDocuments() async {
    final raw = await _storage.read(key: _docKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      final docs = <SecureDocument>[];
      for (final e in list) {
        final doc = SecureDocument.fromJson(e as Map<String, dynamic>);
        if (!doc.hasImage) {
          final image = await _readImageChunks(doc.id);
          docs.add(image == null ? doc : _withImage(doc, image));
        } else {
          docs.add(doc);
        }
      }
      return docs;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveDocuments(List<SecureDocument> docs) async {
    final metadata = <Map<String, dynamic>>[];
    for (final doc in docs) {
      final json = doc.toJson();
      json.remove('imageBase64');
      metadata.add(json);
      if (doc.hasImage) {
        await _writeImageChunks(doc.id, doc.imageBase64!);
      } else {
        await _deleteImageChunks(doc.id);
      }
    }
    final raw = jsonEncode(metadata);
    await _storage.write(key: _docKey, value: raw);
  }

  Future<void> addDocument(SecureDocument doc) async {
    final docs = await getDocuments();
    docs.add(doc);
    await saveDocuments(docs);
  }

  String _newId() => 'doc_${DateTime.now().millisecondsSinceEpoch}';
  String _today() {
    final n = DateTime.now();
    return '${n.day.toString().padLeft(2, '0')}/${n.month.toString().padLeft(2, '0')}/${n.year}';
  }

  /// Add a document captured as a PHOTO (bytes base64-encoded into the vault).
  /// Stored encrypted, on-device only. [title]/[docType] describe it; the image
  /// is the content.
  Future<void> addImageDocument({
    required String title,
    required String docType,
    required String imageBase64,
  }) async {
    await addDocument(SecureDocument(
      id: _newId(),
      title: title,
      docType: docType,
      maskedNumber: 'Image',
      dateAdded: _today(),
      rawContent: 'Stored as image (on-device, encrypted).',
      imageBase64: imageBase64,
    ));
  }

  /// Add a document by its NUMBER (typed or spoken). The full number is kept in
  /// the encrypted vault; only a masked form is shown in lists.
  Future<void> addNumberDocument({
    required String title,
    required String docType,
    required String number,
  }) async {
    await addDocument(SecureDocument(
      id: _newId(),
      title: title,
      docType: docType,
      maskedNumber: SecureDocument.maskNumber(number),
      dateAdded: _today(),
      rawContent: '$docType number: $number',
    ));
  }

  Future<void> deleteDocument(String id) async {
    final docs = await getDocuments();
    docs.removeWhere((d) => d.id == id);
    await saveDocuments(docs);
    await _deleteImageChunks(id);
  }

  SecureDocument _withImage(SecureDocument doc, String image) => SecureDocument(
        id: doc.id,
        title: doc.title,
        docType: doc.docType,
        maskedNumber: doc.maskedNumber,
        dateAdded: doc.dateAdded,
        rawContent: doc.rawContent,
        imageBase64: image,
      );

  Future<void> _writeImageChunks(String id, String image) async {
    await _deleteImageChunks(id);
    final count = (image.length / _imageChunkSize).ceil();
    await _storage.write(
        key: '${_imageChunkPrefix}${id}_count', value: '$count');
    for (var i = 0; i < count; i++) {
      final start = i * _imageChunkSize;
      final end = math.min(start + _imageChunkSize, image.length);
      await _storage.write(
        key: '${_imageChunkPrefix}${id}_$i',
        value: image.substring(start, end),
      );
    }
  }

  Future<String?> _readImageChunks(String id) async {
    final countRaw =
        await _storage.read(key: '${_imageChunkPrefix}${id}_count');
    final count = int.tryParse(countRaw ?? '');
    if (count == null || count <= 0) return null;
    final chunks = <String>[];
    for (var i = 0; i < count; i++) {
      final chunk = await _storage.read(key: '${_imageChunkPrefix}${id}_$i');
      if (chunk == null) return null;
      chunks.add(chunk);
    }
    return chunks.join();
  }

  Future<void> _deleteImageChunks(String id) async {
    final countRaw =
        await _storage.read(key: '${_imageChunkPrefix}${id}_count');
    final count = int.tryParse(countRaw ?? '') ?? 0;
    for (var i = 0; i < count; i++) {
      await _storage.delete(key: '${_imageChunkPrefix}${id}_$i');
    }
    await _storage.delete(key: '${_imageChunkPrefix}${id}_count');
  }

  /// True only when the user has actually set a vault PIN. Callers should force
  /// PIN setup before allowing access when this is false.
  Future<bool> hasPin() async {
    final saved = await _storage.read(key: _pinKey);
    return saved != null && saved.isNotEmpty;
  }

  /// Verify a PIN against the securely-stored value. There is NO default PIN:
  /// if none has been set, verification fails (the UI must prompt setup first).
  Future<bool> verifyPin(String pin) async {
    final savedPin = await _storage.read(key: _pinKey);
    if (savedPin == null || savedPin.isEmpty) return false;
    return pin == savedPin;
  }

  /// Set (or change) the vault PIN. Rejects trivially-weak/empty PINs.
  Future<void> setPin(String newPin) async {
    final p = newPin.trim();
    if (p.length < 4) {
      throw ArgumentError('PIN must be at least 4 digits.');
    }
    await _storage.write(key: _pinKey, value: p);
  }
}
