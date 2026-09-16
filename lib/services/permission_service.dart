import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Запрашивает все разрешения, нужные приложению.
  /// Возвращает true, если всё, что критично, разрешено.
  static Future<bool> ensureAll() async {
    // 1. Камера и микрофон — обязательно
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) return false;

    await Permission.microphone.request();

    // 2. Галерея: на Android 13+ это READ_MEDIA_IMAGES / VIDEO,
    //    на старых — Storage. Gal сам знает, что просить,
    //    но permission_handler даёт единый вход.
    await Permission.photos.request();
    await Permission.videos.request();

    // 3. Fallback для Android 12 и ниже — Storage
    if (await Permission.storage.isDenied) {
      await Permission.storage.request();
    }

    // 4. Финальная проверка через Gal — есть ли доступ к галерее
    final hasGal = await Gal.hasAccess();
    if (!hasGal) {
      await Gal.requestAccess();
    }
    return await Gal.hasAccess();
  }

  /// Проверка без запроса — для UI-подсказок.
  static Future<bool> hasAll() async {
    final camera = await Permission.camera.isGranted;
    final gal = await Gal.hasAccess();
    return camera && gal;
  }
}
