class FilterService {
  // Built-in Flutter/Dart generated file patterns
  static const _generatedPatterns = [
    '.g.dart',
    '.freezed.dart',
    '.mocks.dart',
    'generated_plugin_registrant.dart',
    '.gr.dart', // auto_route
    '.config.dart', // injectable
  ];

  // Extension weights (higher = more important)
  static const _extensionWeights = {
    '.dart': 1.0,
    '.yaml': 0.5,
    '.yml': 0.5,
    '.json': 0.5,
    '.md': 0.1,
    '.txt': 0.1,
    '.png': 0.05,
    '.jpg': 0.05,
    '.svg': 0.05,
    '.lock': 0.0, // Completely ignore
  };

  final List<String> customIgnorePatterns;
  final bool enableFiltering;

  FilterService({
    this.customIgnorePatterns = const [],
    this.enableFiltering = true,
  });

  /// Returns true if the file should be ignored
  bool shouldIgnoreFile(String path) {
    if (!enableFiltering) return false;

    // Check built-in patterns
    for (var pattern in _generatedPatterns) {
      if (path.endsWith(pattern)) return true;
    }

    // Check custom patterns
    for (var pattern in customIgnorePatterns) {
      if (path.contains(pattern)) return true;
    }

    // Check if extension weight is 0 (complete ignore)
    final weight = getFileWeight(path);
    return weight == 0.0;
  }

  /// Returns the weight/priority of a file based on extension
  double getFileWeight(String path) {
    for (var entry in _extensionWeights.entries) {
      if (path.endsWith(entry.key)) {
        return entry.value;
      }
    }
    return 0.3; // Default weight for unknown extensions
  }

  /// Apply weight to a score
  int applyWeight(int baseScore, String path) {
    final weight = getFileWeight(path);
    return (baseScore * weight).round();
  }
}
