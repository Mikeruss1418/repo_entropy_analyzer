class Analyzer {
  /// Parses the git log output and returns file changes count.
  Map<String, int> analyze(String logOutput) {
    final fileCounts = <String, int>{};
    final lines = logOutput.split('\n');

    for (var line in lines) {
      // Basic heuristic: lines starting with space and containing "|" are likely stats
      // Example: " lib/main.dart | 10 +++++++++-"
      // We want to skip:
      // - Commit headers (commit xyz, Author: ..., Date: ...)
      // - Empty lines
      // - Summary lines " 3 files changed, 20 insertions(+)..."

      if (line.trim().isEmpty) continue;

      // Git log --stat lines usually look like " path/to/file | N +-"
      // But verify it has a pipe, and doesn't look like a summary line
      if (line.contains('|') && !line.contains('files changed')) {
        final parts = line.split('|');
        if (parts.length >= 2) {
          final path = parts[0].trim();

          // Basic validation to assume it is a file path
          if (path.isNotEmpty) {
            fileCounts[path] = (fileCounts[path] ?? 0) + 1;
          }
        }
      }
    }
    return fileCounts;
  }
}
