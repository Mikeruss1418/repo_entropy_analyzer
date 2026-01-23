import 'dart:io';
import 'package:args/args.dart';
import 'package:repo_analyzer/rea.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'last',
      abbr: 'l',
      defaultsTo: '50',
      help: 'Number of last commits to analyze',
    )
    ..addOption(
      'top',
      abbr: 't',
      defaultsTo: '10',
      help: 'Number of results to show',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show usage information',
    )
    ..addFlag(
      'version',
      abbr: 'v',
      negatable: false,
      help: 'Show version information',
    )
    ..addFlag(
      'weighted',
      negatable: false,
      help: 'Show weighted score breakdown',
    )
    ..addFlag('authors', negatable: false, help: 'Show author statistics');

  ArgResults argResults;
  try {
    argResults = parser.parse(arguments);
  } catch (e) {
    print('Error: ${e.toString()}');
    print('Usage: rea [options] [path]');
    print(parser.usage);
    exit(1);
  }

  if (argResults['help'] as bool) {
    print('Repo Entropy Analyzer (REA)');
    print('Usage: rea [options] [path]');
    print(parser.usage);
    exit(0);
  }

  if (argResults['version'] as bool) {
    print('Repo Entropy Analyzer (REA) v0.0.2');
    exit(0);
  }

  // Determine repository path
  String path = '.';
  if (argResults.rest.isNotEmpty) {
    path = argResults.rest.first;
  }

  final int lastCommits = int.tryParse(argResults['last'] as String) ?? 50;
  final int topCount = int.tryParse(argResults['top'] as String) ?? 10;
  final bool showWeighted = argResults['weighted'] as bool;
  final bool showAuthors = argResults['authors'] as bool;

  final gitService = GitService();
  final analyzer = Analyzer();
  final metricsEngine = MetricsEngine();

  // Phase 0: Validation
  if (!await gitService.checkGitInstalled()) {
    print('Error: Git is not installed or not in the system PATH.');
    exit(1);
  }

  final gitRoot = await gitService.findGitRoot(path);
  if (gitRoot == null) {
    print("Error: The directory '$path' is not a git repository.");
    exit(1);
  }

  // Phase 1: Data Extraction
  try {
    print('Analyzing last $lastCommits commits in $gitRoot...');

    final logRaw = await gitService.getRawLog(gitRoot, lastCommits);
    final fileHistories = analyzer.analyze(logRaw);

    // Phase 2: Metrics Calculation
    final riskReports = metricsEngine.calculateRisk(fileHistories);

    print('Analyzed ${fileHistories.length} files.');
    print('');
    print('Top $topCount High-Risk Files:');
    print('--------------------------------------------------');

    // Header
    var header =
        '${padRight('File', 40)}${padRight('Score', 10)}${padRight('Risk', 10)}${padRight('Changes', 10)}';
    if (showAuthors) header += padRight('Authors', 10);
    if (showWeighted) header += '  (Details)';
    print(header);

    print('--------------------------------------------------');

    for (var report in riskReports.take(topCount)) {
      final history = fileHistories.firstWhere(
        (h) => h.path == report.filePath,
      );

      var line =
          '${padRight(truncate(report.filePath, 38), 40)}${padRight(report.score.toString(), 10)}${padRight(report.riskLevel, 10)}${padRight(history.changeCount.toString(), 10)}';

      if (showAuthors) {
        final uniqueAuthors = history.commits
            .map((c) => c.authorEmail)
            .toSet()
            .length;
        line += padRight(uniqueAuthors.toString(), 10);
      }

      if (showWeighted) {
        // 1. Raw Change Count (Base Score)
        double score = (history.changeCount * 2).clamp(0, 50).toDouble();

        // 2. Temporal Decay (Recency)
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
        recencyScore = recencyScore.clamp(0, 30);

        // 3. Bus Factor
        int busScore = 0;
        final uniqueAuthors = history.commits.map((c) => c.authorEmail).toSet();
        if (uniqueAuthors.length > 3) {
          busScore = 20;
        } else if (uniqueAuthors.length > 1) {
          busScore = 5;
        }

        line +=
            '  (Base:${score.toInt()} + Recency:${recencyScore.toInt()} + Bus:$busScore)';
      }

      print(line);
    }
  } catch (e) {
    print('Error analyzing repository: $e');
    exit(1);
  }
}

// used just for providing padding between each column
String padRight(String s, int width) {
  return s.padRight(width);
}

String truncate(String s, int max) {
  if (s.length <= max) return s;
  return '...${s.substring(s.length - (max - 3))}';
}
