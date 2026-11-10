import 'package:firebase_database/firebase_database.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class DatabaseService {
  // 1. Reference for the Map-API Realtime Database
  // Use the default Firebase app instance here because it is already initialized
  // by Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform).
  static DatabaseReference mapApiDb([String? path]) {
    final instance = FirebaseDatabase.instance;
    return path != null ? instance.ref(path) : instance.ref();
  }

  Future<String> uploadMediaFile(File file, String pathInStorage) async {
    // 1. Create a reference to the storage location
    final storageRef = FirebaseStorage.instance.ref().child(pathInStorage);

    // 2. Upload the file
    final uploadTask = await storageRef.putFile(file);

    // 3. Get and return the public download URL
    final downloadUrl = await uploadTask.ref.getDownloadURL();
    return downloadUrl;
  }

  Future<void> addMediaToHazard({
    required String hazardId,
    required File mediaFile,
    File? thumbnailFile, // Optional separate thumbnail for videos
    required String type, // 'photo' or 'video'
    required String caption,
    int durationSec = 0,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final mediaId = 'media_$timestamp';

    // 1. Upload main media file to Firebase Storage
    String mediaUrl = await uploadMediaFile(
      mediaFile,
      'hazards/$hazardId/$mediaId.${type == 'video' ? 'mp4' : 'jpg'}',
    );

    // 2. Upload thumbnail if available (otherwise reuse mediaUrl for photos)
    String thumbnailUrl = mediaUrl;
    if (thumbnailFile != null) {
      thumbnailUrl = await uploadMediaFile(
        thumbnailFile,
        'hazards/$hazardId/${mediaId}_thumb.jpg',
      );
    }

    // 3. Save the record in Realtime Database under hazards/{hazardId}/media/{mediaId}
    final DatabaseReference dbRef = FirebaseDatabase.instance.ref(
      'hazards/$hazardId/media/$mediaId',
    );

    await dbRef.set({
      'caption': caption,
      'captured_at': timestamp,
      'duration_sec': durationSec,
      'thumbnail_url': thumbnailUrl,
      'type': type, // "photo" or "video"
      'url': mediaUrl,
    });
  }
}
