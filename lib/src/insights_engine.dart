import 'metrics_engine.dart';

class CoChangePattern {
  final String file1;
  final String file2;
  final double coChangeRate; // 0.0 to 1.0
  final int coChangeCount;

  CoChangePattern(
    this.file1,
    this.file2,
    this.coChangeRate,
    this.coChangeCount,
  );
}

class KnowledgeSilo {
  final String filePath;
  final String soleAuthor;
  final int changeCount;

  KnowledgeSilo(this.filePath, this.soleAuthor, this.changeCount);
}

class InsightsEngine {
  /// Analyzes co-change patterns: files that are frequently changed together
  List<CoChangePattern> analyzeCoChange(List<FileHistory> histories) {
    final patterns = <CoChangePattern>[];

    // Build commit-to-files map
    final commitFiles = <String, Set<String>>{};

    for (var history in histories) {
      for (var commit in history.commits) {
        // Use author+date as commit identifier (not perfect but works)
        final commitId =
            '${commit.authorEmail}|${commit.date.toIso8601String()}';
        commitFiles.putIfAbsent(commitId, () => {}).add(history.path);
      }
    }

    // Find files that appear together frequently
    final filePairs = <String, Map<String, int>>{};

    for (var files in commitFiles.values) {
      if (files.length < 2) continue;

      final fileList = files.toList();
      for (var i = 0; i < fileList.length; i++) {
        for (var j = i + 1; j < fileList.length; j++) {
          final file1 = fileList[i];
          final file2 = fileList[j];

          // Ensure consistent ordering
          final key = file1.compareTo(file2) < 0 ? file1 : file2;
          final value = file1.compareTo(file2) < 0 ? file2 : file1;

          filePairs.putIfAbsent(key, () => {});
          filePairs[key]![value] = (filePairs[key]![value] ?? 0) + 1;
        }
      }
    }

    // Calculate co-change rates
    for (var file1 in filePairs.keys) {
      final history1 = histories.firstWhere(
        (h) => h.path == file1,
        orElse: () => FileHistory(file1, []),
      );

      for (var file2 in filePairs[file1]!.keys) {
        final coChangeCount = filePairs[file1]![file2]!;
        final history2 = histories.firstWhere(
          (h) => h.path == file2,
          orElse: () => FileHistory(file2, []),
        );

        // Calculate Jaccard similarity: intersection / union
        final totalChanges1 = history1.changeCount;
        final totalChanges2 = history2.changeCount;
        final union = totalChanges1 + totalChanges2 - coChangeCount;

        if (union > 0) {
          final coChangeRate = coChangeCount / union;

          // Only report if co-change rate > 70%
          if (coChangeRate > 0.7 && coChangeCount >= 3) {
            patterns.add(
              CoChangePattern(file1, file2, coChangeRate, coChangeCount),
            );
          }
        }
      }
    }

    // Sort by co-change rate descending
    patterns.sort((a, b) => b.coChangeRate.compareTo(a.coChangeRate));

    return patterns;
  }

  /// Finds knowledge silos: high-churn files with only one author
  List<KnowledgeSilo> findKnowledgeSilos(List<FileHistory> histories) {
    final silos = <KnowledgeSilo>[];

    for (var history in histories) {
      final uniqueAuthors = history.commits.map((c) => c.authorEmail).toSet();

      // Knowledge silo: >10 changes but only 1 author
      if (history.changeCount > 10 && uniqueAuthors.length == 1) {
        silos.add(
          KnowledgeSilo(history.path, uniqueAuthors.first, history.changeCount),
        );
      }
    }

    // Sort by change count descending
    silos.sort((a, b) => b.changeCount.compareTo(a.changeCount));

    return silos;
  }
}
