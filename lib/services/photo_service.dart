import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../core/session.dart';

/// Escolhe uma imagem e sobe para o storage da API.
class PhotoService {
  static final ImagePicker _picker = ImagePicker();

  static Future<XFile?> pick({required ImageSource source}) {
    return _picker.pickImage(
      source: source,
      maxWidth: 1440,
      imageQuality: 82,
    );
  }

  /// Faz o upload e devolve a URL pública da imagem.
  static Future<String> upload(XFile file) async {
    final bytes = await file.readAsBytes();
    return ApiClient.uploadImage(bytes, _safeName(file.name));
  }

  /// A API só aceita jpg/jpeg/png e usa o nome do arquivo como nome do blob,
  /// então geramos um nome único com extensão válida.
  static String _safeName(String original) {
    final lower = original.toLowerCase();
    final extension = lower.endsWith('.png') ? 'png' : 'jpg';
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return 'workut_${Session.instance.userId}_$stamp.$extension';
  }
}
