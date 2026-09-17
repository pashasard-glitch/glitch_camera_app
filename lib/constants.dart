class EffectFlags {
  static const int rgbSplit = 1;
  static const int vhsScan = 2;
  static const int datamosh = 4;
  static const int noise = 8;
  static const int invertPulse = 16;
  static const int acidTint = 32;
  static const int slitScan = 64;

  static const List<MapEntry<String, int>> all = [
    MapEntry('RGB SPLIT', rgbSplit),
    MapEntry('VHS SCAN', vhsScan),
    MapEntry('DATAMOSH', datamosh),
    MapEntry('NOISE', noise),
    MapEntry('INVERT PULSE', invertPulse),
    MapEntry('ACID TINT', acidTint),
    MapEntry('SLIT SCAN', slitScan),
  ];
}
