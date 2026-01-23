import 'dart:io';

class ReaConfig {
  final int lastCommits;
  final List<String> ignorePatterns;
  final List<String> extensions;
  final bool enableColors;

  ReaConfig({
    this.lastCommits = 50,
    this.ignorePatterns = const [],
    this.extensions = const [],
    this.enableColors = true,
  });

  factory ReaConfig.fromMap(Map<String, dynamic> map) {
    return ReaConfig(
      lastCommits: map['last_commits'] as int? ?? 50,
      ignorePatterns: (map['ignore'] as List?)?.cast<String>() ?? [],
      extensions: (map['extensions'] as List?)?.cast<String>() ?? [],
      enableColors: map['enable_colors'] as bool? ?? true,
    );
  }
}

class ConfigLoader {
  /// Loads .rea.yaml config from the given directory
  static Future<ReaConfig?> loadConfig(String repoPath) async {
    final configFile = File('$repoPath/.rea.yaml');

    if (!await configFile.exists()) {
      return null; // No config file
    }

    try {
      final content = await configFile.readAsString();
      // Simple YAML parsing (key: value)
      final map = <String, dynamic>{};
      final lines = content.split('\n');

      String? currentKey;
      List<String>? currentList;

      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty || line.startsWith('#')) continue;

        // Check for list items FIRST (before checking for ':')
        if (line.startsWith('-') && currentList != null) {
          // List item
          final item = line.substring(1).trim();
          currentList.add(item);
        } else if (line.contains(':')) {
          // Use indexOf to find first colon, then substring to preserve additional colons
          final colonIndex = line.indexOf(':');
          final key = line.substring(0, colonIndex).trim();
          final value = colonIndex + 1 < line.length
              ? line.substring(colonIndex + 1).trim()
              : '';

          if (value.isEmpty) {
            // Start of a list
            currentKey = key;
            currentList = [];
            map[key] = currentList;
          } else {
            // Simple key-value
            currentKey = null;
            currentList = null;

            if (value == 'true') {
              map[key] = true;
            } else if (value == 'false') {
              map[key] = false;
            } else if (int.tryParse(value) != null) {
              map[key] = int.parse(value);
            } else {
              map[key] = value;
            }
          }
        }
      }

      return ReaConfig.fromMap(map);
    } catch (e) {
      print('Warning: Failed to parse .rea.yaml: $e');
      return null;
    }
  }
}
