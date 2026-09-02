import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../core/api_constants.dart';
import '../core/session.dart';

/// Escolhe uma imagem e sobe para o storage da API (somente perfil).
class PhotoService {
  static final ImagePicker _picker = ImagePicker();

  static Future<XFile?> pick({required ImageSource source}) {
    return _picker.pickImage(
      source: source,
      maxWidth: 1440,
      imageQuality: 82,
    );
  }

  /// Upload de foto de perfil para `File/v1/uploadProfile`.
  static Future<String> uploadProfile(XFile file) async {
    final bytes = await file.readAsBytes();
    return ApiClient.uploadProfileImage(bytes, _safeName(file.name));
  }

  static String _safeName(String original) {
    final lower = original.toLowerCase();
    final extension = lower.endsWith('.png') ? 'png' : 'jpg';
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return 'profile_${Session.instance.userId}_$stamp.$extension';
  }
}
