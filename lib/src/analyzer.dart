import 'metrics_engine.dart';
import 'filter_service.dart';

class Analyzer {
  final FilterService? filterService;

  Analyzer({this.filterService});

  /// Parses the git log output and returns structured file history.
  List<FileHistory> analyze(String logOutput) {
    // Legacy support or fallback
    // Re-implement or call stream version?
    // Calling stream version is async, this is sync.
    // Let's keep this as reference or duplicate logic efficiently?
    // Actually, let's keep it for compatibility if needed, but we will move to stream.
    // But since we want to migrate, let's just create analyzeStream and refactor callers.
    final lines = logOutput.split('\n');
    return _analyzeLines(lines);
  }

  Future<List<FileHistory>> analyzeStream(Stream<String> logStream) async {
    final fileCommits = <String, List<CommitInfo>>{};
    CommitInfo? currentCommit;

    await for (var line in logStream) {
      _processLine(
        line.trim(),
        fileCommits,
        (c) => currentCommit = c,
        () => currentCommit,
      );
    }

    return fileCommits.entries.map((e) => FileHistory(e.key, e.value)).toList();
  }

  // Refactored helper to share logic (simulated for now, inline is fine for speed)
  List<FileHistory> _analyzeLines(List<String> lines) {
    final fileCommits = <String, List<CommitInfo>>{};
    CommitInfo? currentCommit;

    for (var line in lines) {
      _processLine(
        line.trim(),
        fileCommits,
        (c) => currentCommit = c,
        () => currentCommit,
      );
    }
    return fileCommits.entries.map((e) => FileHistory(e.key, e.value)).toList();
  }

  void _processLine(
    String line,
    Map<String, List<CommitInfo>> fileCommits,
    Function(CommitInfo?) setCommit,
    CommitInfo? Function() getCommit,
  ) {
    if (line.isEmpty) return;

    if (line.startsWith('COMMIT_START|')) {
      // Parse Header: COMMIT_START|email|date
      final parts = line.split('|');
      if (parts.length >= 3) {
        final email = parts[1];
        final dateStr = parts[2];
        final date = DateTime.tryParse(dateStr) ?? DateTime.now();
        setCommit(CommitInfo(email, date));
      }
    } else {
      // It's a file path
      if (getCommit() != null) {
        final path = line;

        // Apply filtering
        if (filterService != null && filterService!.shouldIgnoreFile(path)) {
          return; // Skip this file
        }

        fileCommits.putIfAbsent(path, () => []).add(getCommit()!);
      }
    }
  }
}
