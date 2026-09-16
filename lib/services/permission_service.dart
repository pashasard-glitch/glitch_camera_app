import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Запрашивает все разрешения, нужные приложению.
  static Future<bool> ensureAll() async {
    // 1. Камера и микрофон
    final camera = await Permission.camera.request();
    if (!camera.isGranted) return false;
    await Permission.microphone.request();

    // 2. Фото/видео/аудио в галерее (Android 13+)
    await Permission.photos.request();
    await Permission.videos.request();
    await Permission.audio.request();

    // 3. Хранилище (Android 12 и ниже)
    if (await Permission.storage.isDenied) {
      await Permission.storage.request();
    }

    // 4. Управление всеми файлами (Android 11+)
    //    Это разрешение не показывается обычным диалогом,
    //    его нужно включать в системных настройках.
    if (await Permission.manageExternalStorage.isDenied) {
      await Permission.manageExternalStorage.request();
    }

    // 5. Gal: финальная проверка + запрос, если что-то не так
    final hasGal = await Gal.hasAccess();
    if (!hasGal) {
      await Gal.requestAccess();
    }
    return await Gal.hasAccess();
  }

  /// Проверка без запроса — для UI.
  static Future<bool> hasAll() async {
    final camera = await Permission.camera.isGranted;
    final gal = await Gal.hasAccess();
    return camera && gal;
  }
}
