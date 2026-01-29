import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:repo_analyzer/rea.dart';

class DiffCommand extends Command<int> {
  final Logger logger;

  DiffCommand(this.logger) {
    argParser.addOption(
      'last',
      abbr: 'l',
      defaultsTo: '50',
      help: 'Number of last commits to analyze context for',
    );
  }

  @override
  String get name => 'diff';

  @override
  String get description =>
      'Compare current work against a target branch to find entropy risks.';

  @override
  Future<int> run() async {
    final targetBranch = argResults!.rest.isNotEmpty
        ? argResults!.rest.first
        : 'staging';
    final int lastCommits =
        int.tryParse(argResults?['last'] as String? ?? '50') ?? 50;

    final gitService = GitService();

    // 1. Check Git
    if (!await gitService.checkGitInstalled()) {
      logger.err('Git is not installed.');
      return ExitCode.software.code;
    }

    final gitRoot = await gitService.findGitRoot('.');
    if (gitRoot == null) {
      logger.err('Not a git repository.');
      return ExitCode.usage.code;
    }

    logger.info('Comparing current work against "$targetBranch"...');

    // 2. Get Changed Files
    List<String> changedFiles;
    try {
      changedFiles = await gitService.getChangedFiles(gitRoot, targetBranch);
      if (changedFiles.isEmpty) {
        logger.success('No changes detected against $targetBranch.');
        return ExitCode.success.code;
      }
      logger.info('Detected ${changedFiles.length} modified files.');
    } catch (e) {
      logger.err('Error getting diff: $e');
      return ExitCode.software.code;
    }

    // 3. Analyze Risks
    final progress = logger.progress('Calculating entropy risks...');
    final analyzer = Analyzer(
      filterService: FilterService(enableFiltering: true),
    ); // Default filter
    final metricsEngine = MetricsEngine();

    try {
      final logStream = gitService.getRawLogStream(gitRoot, lastCommits);
      final fileHistories = await analyzer.analyzeStream(logStream);
      final riskReports = metricsEngine.calculateRisk(fileHistories);
      progress.complete();

      final dangerousChanges = riskReports
          .where((r) => changedFiles.contains(r.filePath))
          .toList();

      if (dangerousChanges.isEmpty) {
        logger.success(
          '✓ Safe! You are modifying files with low/no recent churn.',
        );
      } else {
        logger.warn('⚠️  SAFETY WARNING ⚠️');
        logger.warn(
          'You are modifying High-Entropy files. Proceed with caution!\n',
        );

        var header =
            '${padRight('File', 40)}${padRight('Score', 10)}${padRight('Risk', 10)}${padRight('Changes', 10)}';
        logger.info(header);
        logger.info('--------------------------------------------------');
        

        bool criticalFound = false;
        for (var report in dangerousChanges) {
          final history = fileHistories.firstWhere(
            (h) => h.path == report.filePath,
          );

          final scoreStr = _colorizeScore(report.score);
          final riskStr = _colorizeRisk(report.riskLevel);

          var line =
              '${padRight(truncate(report.filePath, 38), 40)}${padRight(scoreStr, 10 + (scoreStr.length - report.score.toString().length))}${padRight(riskStr, 10 + (riskStr.length - report.riskLevel.length))}${padRight(history.changeCount.toString(), 10)}';
          logger.info(line);

          if (report.score >= 80) criticalFound = true;
        }

        if (criticalFound) {
          logger.info('');
          logger.alert(
            '🛑 STOP! You are modifying CRITICAL Hotspots (>80 score).',
          );
          logger.info(
            'Double-check your logic and ensure tests cover these changes.',
          );
        }
      }

      return ExitCode.success.code;
    } catch (e) {
      progress.fail();
      logger.err('Error analyzing risk: $e');
      return ExitCode.software.code;
    }
  }

  // Duplicated helpers (should move to a Mixin or Util)
  String _colorizeScore(int score) {
    if (score >= 80) return lightRed.wrap(score.toString())!;
    if (score >= 60) return lightYellow.wrap(score.toString())!;
    if (score >= 40) return lightCyan.wrap(score.toString())!;
    return lightGreen.wrap(score.toString())!;
  }

  String _colorizeRisk(String risk) {
    switch (risk) {
      case 'CRITICAL':
        return lightRed.wrap(risk)!;
      case 'HIGH':
        return lightYellow.wrap(risk)!;
      case 'MEDIUM':
        return lightCyan.wrap(risk)!;
      case 'LOW':
        return lightGreen.wrap(risk)!;
      default:
        return risk;
    }
  }

  String padRight(String s, int width) {
    final stripped = s.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');
    final padding = width - stripped.length;
    if (padding <= 0) return s;
    return s + (' ' * padding);
  }

  String truncate(String s, int max) {
    if (s.length <= max) return s;
    return '...${s.substring(s.length - (max - 3))}';
  }
}
