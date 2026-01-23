import 'dart:io';
import 'package:args/args.dart';
import 'package:repo_analyzer/rea.dart';

Future<void> main(List<String> arguments) async {
  // Detect command BEFORE parsing
  String? command;
  List<String> parserArgs = arguments;

  if (arguments.isNotEmpty && arguments.first == 'diff') {
    command = 'diff';
    // Pass all arguments after 'diff' to the parser (preserves option values)
    parserArgs = arguments.skip(1).toList();
  }

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
    ..addFlag('authors', negatable: false, help: 'Show author statistics')
    ..addFlag(
      'no-filter',
      negatable: false,
      help: 'Disable filtering of generated files',
    )
    ..addFlag('heatmap', negatable: false, help: 'Show ASCII heatmap bars')
    ..addFlag('trend', negatable: false, help: 'Show stability trend indicator')
    ..addFlag('color', defaultsTo: true, help: 'Enable colored output')
    ..addFlag(
      'verbose',
      negatable: false,
      help: 'Analyze all commits and show all files',
    );

  ArgResults argResults;
  try {
    argResults = parser.parse(parserArgs);
  } catch (e) {
    print('Error: ${e.toString()}');
    print('Usage: rea [options] [path]');
    print('       rea diff [target_branch] [options]');
    print(parser.usage);
    exit(1);
  }

  if (argResults['help'] as bool) {
    print('Repo Entropy Analyzer (REA)');
    print('Usage: rea [options] [path]');
    print('       rea diff [target_branch] [options]');
    print(parser.usage);
    exit(0);
  }

  if (argResults['version'] as bool) {
    print('Repo Entropy Analyzer (REA) v0.0.2');
    exit(0);
  }

  // Determine repository path
  String path = '.';
  if (command == null && argResults.rest.isNotEmpty) {
    path = argResults.rest.first;
  }

  final bool verbose = argResults['verbose'] as bool;

  // If verbose, analyze all commits and show all files
  final int lastCommits = verbose
      ? 999999 // Effectively "all" commits
      : (int.tryParse(argResults['last'] as String) ?? 50);
  final int topCount = verbose
      ? 999999 // Show all files
      : (int.tryParse(argResults['top'] as String) ?? 10);

  final bool showWeighted = argResults['weighted'] as bool;
  final bool showAuthors = argResults['authors'] as bool;
  final bool noFilter = argResults['no-filter'] as bool;
  final bool showHeatmap = argResults['heatmap'] as bool;
  final bool showTrend = argResults['trend'] as bool;
  final bool enableColor = argResults['color'] as bool;

  final gitService = GitService();

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

  // Load config
  Visualizer.showProgress('Loading configuration');
  final config = await ConfigLoader.loadConfig(gitRoot);

  // Create filter service
  final filterService = FilterService(
    enableFiltering: !noFilter,
    customIgnorePatterns: config?.ignorePatterns ?? [],
  );

  final analyzer = Analyzer(filterService: filterService);
  final metricsEngine = MetricsEngine();

  if (command == 'diff') {
    // --- DIFF COMMAND EXECUTION ---
    // Get target branch from remaining args (after flags are parsed)
    final targetBranch = argResults.rest.isNotEmpty
        ? argResults.rest.first
        : 'main';
    print('Comparing current work against "$targetBranch"...');

    // 1. Get changed files
    List<String> changedFiles;
    try {
      changedFiles = await gitService.getChangedFiles(gitRoot, targetBranch);
      if (changedFiles.isEmpty) {
        print('No changes detected against $targetBranch.');
        exit(0);
      }
      print('Detected ${changedFiles.length} modified files.');
    } catch (e) {
      print('Error getting diff: $e');
      exit(1);
    }

    // 2. Run Analysis to get Risk Scores
    try {
      final logRaw = await gitService.getRawLog(gitRoot, lastCommits);
      final fileHistories = analyzer.analyze(logRaw);
      final riskReports = metricsEngine.calculateRisk(fileHistories);

      // 3. Filter reports for changed files
      final dangerousChanges = riskReports
          .where((r) => changedFiles.contains(r.filePath))
          .toList();

      if (dangerousChanges.isEmpty) {
        print('✓ Safe! You are modifying files with low/no recent churn.');
      } else {
        print('');
        print('⚠️  SAFETY WARNING ⚠️');
        print('You are modifying High-Entropy files. Proceed with caution!');
        print('');

        var header =
            '${padRight('File', 40)}${padRight('Score', 10)}${padRight('Risk', 10)}${padRight('Changes', 10)}';
        print(header);
        print('--------------------------------------------------');

        bool criticalFound = false;

        for (var report in dangerousChanges) {
          final history = fileHistories.firstWhere(
            (h) => h.path == report.filePath,
          );
          var line =
              '${padRight(truncate(report.filePath, 38), 40)}${padRight(report.score.toString(), 10)}${padRight(report.riskLevel, 10)}${padRight(history.changeCount.toString(), 10)}';
          print(line);

          if (report.score >= 80) criticalFound = true;
        }

        if (criticalFound) {
          print('');
          print('🛑 STOP! You are modifying CRITICAL Hotspots (>80 score).');
          print(
            'Double-check your logic and ensure tests cover these changes.',
          );
        }
      }
    } catch (e) {
      print('Error analyzing risk: $e');
      exit(1);
    }
  } else {
    // --- STANDARD ANALYSIS ---
    try {
      print('Analyzing last $lastCommits commits in $gitRoot...');

      final logRaw = await gitService.getRawLog(gitRoot, lastCommits);
      final fileHistories = analyzer.analyze(logRaw);

      // Phase 2: Metrics Calculation
      final riskReports = metricsEngine.calculateRisk(fileHistories);

      print('Analyzed ${fileHistories.length} files.');

      // Calculate stability trend if requested
      if (showTrend && lastCommits >= 50) {
        try {
          // Get previous period for comparison
          final prevLogRaw = await gitService.getRawLog(
            gitRoot,
            lastCommits * 2,
          );
          final prevHistories = analyzer.analyze(prevLogRaw);
          final prevReports = metricsEngine.calculateRisk(prevHistories);

          // Create score maps
          final recentScores = {for (var r in riskReports) r.filePath: r.score};
          final prevScores = {for (var r in prevReports) r.filePath: r.score};

          final trend = Visualizer.calculateStabilityTrend(
            recentScores,
            prevScores,
          );
          print('Stability Trend: $trend');
        } catch (e) {
          // Trend calculation failed, continue without it
        }
      }

      print('');
      print('Top $topCount High-Risk Files:');
      print('--------------------------------------------------');

      // Header
      var header =
          '${padRight('File', 40)}${padRight('Score', 10)}${padRight('Risk', 10)}${padRight('Changes', 10)}';
      if (showHeatmap) header += padRight('Heatmap', 25);
      if (showAuthors) header += padRight('Authors', 10);
      if (showWeighted) header += '  (Details)';
      print(header);

      print('--------------------------------------------------');

      for (var report in riskReports.take(topCount)) {
        final history = fileHistories.firstWhere(
          (h) => h.path == report.filePath,
        );

        final scoreStr = enableColor
            ? Visualizer.colorizeScore(report.score)
            : report.score.toString();
        final riskStr = enableColor
            ? Visualizer.colorizeRisk(report.riskLevel)
            : report.riskLevel;

        var line =
            '${padRight(truncate(report.filePath, 38), 40)}${padRight(scoreStr, 10)}${padRight(riskStr, 10)}${padRight(history.changeCount.toString(), 10)}';

        if (showHeatmap) {
          line += padRight(Visualizer.generateHeatBar(report.score), 25);
        }

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
          final uniqueAuthors = history.commits
              .map((c) => c.authorEmail)
              .toSet();
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
}

// used just for providing padding between each column
String padRight(String s, int width) {
  // Remove ANSI color codes for length calculation
  final stripped = s.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');
  final padding = width - stripped.length;

  if (padding <= 0) return s;
  return s + (' ' * padding);
}

String truncate(String s, int max) {
  if (s.length <= max) return s;
  return '...${s.substring(s.length - (max - 3))}';
}
