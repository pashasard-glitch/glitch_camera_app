enum TrackingMode { random, grid, focus }

class TrackerConfig {
  final String id;
  final String label;
  final double sizeFrac;
  final bool randomTag;

  TrackerConfig({
    required this.id,
    required this.label,
    required this.sizeFrac,
    this.randomTag = false,
  });

  TrackerConfig copyWith({String? label, double? sizeFrac, bool? randomTag}) {
    return TrackerConfig(
      id: id,
      label: label ?? this.label,
      sizeFrac: sizeFrac ?? this.sizeFrac,
      randomTag: randomTag ?? this.randomTag,
    );
  }

  static List<TrackerConfig> defaults() {
    return [
      TrackerConfig(id: 't1', label: 'TRACKING', sizeFrac: 0.18),
      TrackerConfig(id: 't2', label: 'SCANNING', sizeFrac: 0.16),
      TrackerConfig(id: 't3', label: 'LOCKED', sizeFrac: 0.20),
      TrackerConfig(id: 't4', label: 'ANALYZING', sizeFrac: 0.17),
    ];
  }
}
