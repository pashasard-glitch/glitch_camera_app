import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> ensureAll() async {
    final camera = await Permission.camera.request();
    if (!camera.isGranted) return false;

    await Permission.microphone.request();

    final hasGal = await Gal.hasAccess();
    if (!hasGal) {
      final granted = await Gal.requestAccess();
      return granted;
    }
    return true;
  }

  static Future<bool> hasAll() async {
    final camera = await Permission.camera.isGranted;
    final gal = await Gal.hasAccess();
    return camera && gal;
  }
}
