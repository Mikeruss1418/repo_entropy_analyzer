import 'metrics_engine.dart';

class Analyzer {
  /// Parses the git log output and returns structured file history.
  List<FileHistory> analyze(String logOutput) {
    final fileCommits = <String, List<CommitInfo>>{};

    final lines = logOutput.split('\n');
    CommitInfo? currentCommit;

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('COMMIT_START|')) {
        // Parse Header: COMMIT_START|email|date
        final parts = line.split('|');
        if (parts.length >= 3) {
          final email = parts[1];
          final dateStr = parts[2];
          final date = DateTime.tryParse(dateStr) ?? DateTime.now();
          currentCommit = CommitInfo(email, date);
        }
      } else {
        // It's a file path
        if (currentCommit != null) {
          final path = line;
          fileCommits.putIfAbsent(path, () => []).add(currentCommit);
        }
      }
    }

    return fileCommits.entries.map((e) => FileHistory(e.key, e.value)).toList();
  }
}
