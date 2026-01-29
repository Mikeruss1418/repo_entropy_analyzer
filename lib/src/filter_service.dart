import 'dart:io';
import 'package:glob/glob.dart';

class FilterService {
  // Built-in Flutter/Dart generated file patterns
  static const _generatedPatterns = [
    '**.g.dart',
    '**.freezed.dart',
    '**.mocks.dart',
    '**generated_plugin_registrant.dart',
    '**.gr.dart', // auto_route
    '**.config.dart', // injectable
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

  final List<Glob> ignoreGlobs;
  final bool enableFiltering;

  FilterService({
    List<String> customIgnorePatterns = const [],
    this.enableFiltering = true,
  }) : ignoreGlobs = [
         ..._generatedPatterns.map((p) => Glob(p)),
         ...customIgnorePatterns.map((p) => Glob(p)),
       ];

  /// Loads .gitignore patterns from the given root directory
  static Future<List<String>> loadGitIgnore(String gitRoot) async {
    final gitIgnoreFile = File('$gitRoot/.gitignore');
    if (!await gitIgnoreFile.exists()) return [];

    try {
      final lines = await gitIgnoreFile.readAsLines();
      return lines
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && !l.startsWith('#'))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Returns true if the file should be ignored
  bool shouldIgnoreFile(String path) {
    if (!enableFiltering) return false;

    // Check extension weight first (fastest)
    final weight = getFileWeight(path);
    if (weight == 0.0) return true;

    // Check globs
    // We assume path is relative to root, or we handle standard paths
    // Git log usually returns relative paths from root
    for (var glob in ignoreGlobs) {
      if (glob.matches(path)) return true;
    }

    return false;
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
