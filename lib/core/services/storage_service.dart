import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Cross-platform image upload service using firebase_storage + image_picker.
/// Works on Android (gallery/camera) and Web (file picker).
class StorageService {
  static final _picker = ImagePicker();
  static final _storage = FirebaseStorage.instance;

  /// Pick one or more images from gallery/file picker.
  static Future<List<XFile>> pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 80);
    return picked;
  }

  /// Upload a single [XFile] to [storagePath] and return the download URL.
  static Future<String> uploadImage(XFile file, String storagePath) async {
    final bytes = await file.readAsBytes();
    final ext = file.name.split('.').last.toLowerCase();
    final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
    final ref = _storage.ref().child(storagePath);
    final snapshot = await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    return await snapshot.ref.getDownloadURL();
  }

  /// Upload multiple images for a venue. Returns new download URLs.
  static Future<List<String>> uploadVenueImages(
    String venueId,
    List<XFile> images,
  ) async {
    final urls = <String>[];
    for (final img in images) {
      final ts = DateTime.now().microsecondsSinceEpoch;
      final url = await uploadImage(img, 'venues/$venueId/$ts.jpg');
      urls.add(url);
    }
    return urls;
  }

  /// Upload multiple images for a zone. Returns new download URLs.
  static Future<List<String>> uploadZoneImages(
    String zoneId,
    List<XFile> images,
  ) async {
    final urls = <String>[];
    for (final img in images) {
      final ts = DateTime.now().microsecondsSinceEpoch;
      final url = await uploadImage(img, 'zones/$zoneId/$ts.jpg');
      urls.add(url);
    }
    return urls;
  }

  /// Delete an image by its full Firebase Storage download URL.
  static Future<void> deleteImage(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {}
  }
}
