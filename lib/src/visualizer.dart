import 'package:repo_analyzer/rea.dart';

class Visualizer {
  /// Generates an ASCII heatbar for a score (0-100)
  /// Example: [##########----------] 50%
  static String generateHeatBar(int score, {int width = 20}) {
    final filled = (score / 100 * width).round().clamp(0, width);
    final empty = width - filled;

    final bar = '#' * filled + '-' * empty;
    return '[$bar] $score%';
  }

  /// Calculates stability trend by comparing two sets of file histories
  /// Returns: ↑ (worse), ↓ (better), → (stable)
  static String calculateStabilityTrend(
    Map<String, int> recentScores,
    Map<String, int> previousScores,
  ) {
    if (recentScores.isEmpty || previousScores.isEmpty) {
      return '→'; // No data to compare
    }

    // Calculate average scores
    final recentAvg =
        recentScores.values.reduce((a, b) => a + b) / recentScores.length;
    final previousAvg =
        previousScores.values.reduce((a, b) => a + b) / previousScores.length;

    final diff = recentAvg - previousAvg;

    if (diff > 5) return 'Volatile ↑'; // Getting worse
    if (diff < -5) return 'Getting Better ↓'; // Getting better
    return 'Stable →'; // Stable
  }

  /// Simple progress indicator
  static void showProgress(String message) {
    // Simple dot animation would require async, so just print message
    print('$message...');
  }

  /// Color code for risk level (using ANSI codes)
  static String colorizeRisk(String riskLevel) {
    switch (riskLevel) {
      case 'CRITICAL':
        return '\x1B[31m$riskLevel\x1B[0m'; // Red
      case 'HIGH':
        return '\x1B[33m$riskLevel\x1B[0m'; // Yellow
      case 'MEDIUM':
        return '\x1B[36m$riskLevel\x1B[0m'; // Cyan
      case 'LOW':
        return '\x1B[32m$riskLevel\x1B[0m'; // Green
      default:
        return riskLevel;
    }
  }

  /// Format score with color
  static String colorizeScore(int score) {
    if (score >= 80) return '\x1B[31m$score\x1B[0m'; // Red
    if (score >= 60) return '\x1B[33m$score\x1B[0m'; // Yellow
    if (score >= 40) return '\x1B[36m$score\x1B[0m'; // Cyan
    return '\x1B[32m$score\x1B[0m'; // Green
  }

  /// Calculate weighted components for display
  static String calculateWeightedComponents(
    RiskReport report,
    FileHistory history,
  ) {
    // Calculate individual component scores
    // These weights should match what MetricsEngine uses
    final changeFrequency = (history.changeCount * 0.4).toInt();

    final uniqueAuthors = history.commits
        .map((c) => c.authorEmail)
        .toSet()
        .length;
    final authorComplexity = (uniqueAuthors * 0.3).toInt();

    // Calculate recency score (more recent changes = higher score)
    int recencyScore = 0;
    if (history.commits.isNotEmpty) {
      final latestCommit = history.commits.first.date;
      final now = DateTime.now();
      final daysSinceLastChange = now.difference(latestCommit).inDays;

      if (daysSinceLastChange < 7) {
        recencyScore = 30;
      } else if (daysSinceLastChange < 30) {
        recencyScore = 20;
      } else if (daysSinceLastChange < 90) {
        recencyScore = 10;
      } else {
        recencyScore = 5;
      }
    }

    return 'Freq:$changeFrequency   Auth:$authorComplexity    Rec:$recencyScore';
  }
}
