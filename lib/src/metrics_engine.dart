class FileHistory {
  final String path;
  final List<CommitInfo> commits;

  FileHistory(this.path, this.commits);

  int get changeCount => commits.length;
}

class CommitInfo {
  final String authorEmail;
  final DateTime date;

  CommitInfo(this.authorEmail, this.date);
}

class RiskReport {
  final String filePath;
  final int score; // 0-100
  final String riskLevel; // LOW, MEDIUM, HIGH, CRITICAL

  RiskReport(this.filePath, this.score, this.riskLevel);
}

class MetricsEngine {
  /// Calculates risk scores for all files.
  List<RiskReport> calculateRisk(List<FileHistory> histories) {
    final reports = <RiskReport>[];

    for (var history in histories) {
      final score = _calculateEntropyScore(history);
      final riskLevel = _getRiskLevel(score);
      reports.add(RiskReport(history.path, score, riskLevel));
    }

    // Sort by score descending
    reports.sort((a, b) => b.score.compareTo(a.score));
    return reports;
  }

  int _calculateEntropyScore(FileHistory history) {
    if (history.commits.isEmpty) return 0;

    double score = 0.0;

    // 1. Raw Change Count (Base Score)
    // Cap at 50 points for raw churn
    score += (history.changeCount * 2).clamp(0, 50);

    // 2. Temporal Decay (Recency)
    // Recent changes add more risk
    double recencyScore = 0.0;
    final now = DateTime.now();
    for (var commit in history.commits) {
      final daysAgo = now.difference(commit.date).inDays;
      if (daysAgo <= 7) {
        recencyScore += 3.0; // High impact
      } else if (daysAgo <= 30) {
        recencyScore += 1.0; // Medium impact
      } else {
        recencyScore += 0.1; // Low impact
      }
    }
    score += recencyScore.clamp(0, 30); // Cap at 30 points

    // 3. Bus Factor (Author Diversity)
    // More unique authors = Higher risk (Confusion/Conflict zone)
    final uniqueAuthors = history.commits.map((c) => c.authorEmail).toSet();
    if (uniqueAuthors.length > 3) {
      score += 20; // High risk multiplier
    } else if (uniqueAuthors.length > 1) {
      score += 5;
    }

    return score.round().clamp(0, 100);
  }

  String _getRiskLevel(int score) {
    if (score >= 80) return 'CRITICAL';
    if (score >= 60) return 'HIGH';
    if (score >= 40) return 'MEDIUM';
    return 'LOW';
  }

  /// Aggregates risk scores by directory
  Map<String, int> calculateDirectoryRisk(List<RiskReport> reports) {
    final dirScores = <String, List<int>>{};

    for (var report in reports) {
      final parts = report.filePath.split('/');
      if (parts.length > 1) {
        // Use first level directory or full path?
        // Let's use first level top-level directories for high level view
        // Or recursivley?
        // Let's go with immediate parent directory of the file for granular heatmap,
        // OR top-level folders.
        // Requirement: "The auth/ module has a risk score of 80" suggests module based.
        // Let's use the top-level directory (e.g. lib, bin, test, or src within lib)
        // Adjust logic: if starts with lib/, take lib/src or lib/foo.

        String dir = parts.first;
        if (dir == 'lib' && parts.length > 2) {
          dir = 'lib/${parts[1]}';
        } else if (parts.length > 1) {
          dir = parts.first; // e.g. bin
        }

        dirScores.putIfAbsent(dir, () => []).add(report.score);
      } else {
        dirScores.putIfAbsent('root', () => []).add(report.score);
      }
    }

    final aggregated = <String, int>{};
    dirScores.forEach((dir, scores) {
      if (scores.isEmpty) return;
      // Average score? Max score?
      // Average might hide hotspots. Max warns about hotspots.
      // Let's use Average for "Health" and Max for "Risk".
      // Let's use Average.
      final avg = scores.reduce((a, b) => a + b) / scores.length;
      aggregated[dir] = avg.round();
    });

    // Sort by score desc
    return Map.fromEntries(
      aggregated.entries.toList()
        ..sort((e1, e2) => e2.value.compareTo(e1.value)),
    );
  }
}
