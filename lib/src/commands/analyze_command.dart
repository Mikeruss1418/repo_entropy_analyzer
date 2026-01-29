import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:repo_analyzer/rea.dart';

class AnalyzeCommand extends Command<int> {
  final Logger logger;

  AnalyzeCommand(this.logger) {
    argParser
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
      ..addFlag(
        'trend',
        negatable: false,
        help: 'Show stability trend indicator',
      )
      // Note: color is handled by mason_logger largely, but kept for logic
      ..addFlag('color', defaultsTo: true, help: 'Enable colored output')
      ..addFlag(
        'verbose', // Renaming 'all' logic to be clearer if needed, but keeping 'verbose' as logic
        negatable: false,
        help:
            'Analyze all commits and show all files (overrides --last and --top)',
      )
      ..addFlag(
        'insights',
        negatable: false,
        help: 'Show co-change patterns and knowledge silos',
      )
      ..addOption(
        'export',
        allowed: ['html', 'json', 'both'],
        help: 'Export report (html, json, or both)',
      )
      ..addOption(
        'output',
        abbr: 'o',
        defaultsTo: 'rea_report',
        help: 'Output file path (without extension)',
      )
      ..addFlag(
        'interactive',
        abbr: 'i',
        negatable: false,
        help: 'Enable interactive mode to inspect specific files',
      );
  }

  @override
  String get name => 'analyze';

  @override
  String get description => 'Analyze repository entropy and churn.';

  @override
  Future<int> run() async {
    // 1. Parse Args
    final bool verbose = argResults?['verbose'] as bool;
    final int lastCommits = verbose
        ? 999999
        : (int.tryParse(argResults?['last'] as String? ?? '50') ?? 50);
    final int topCount = verbose
        ? 999999
        : (int.tryParse(argResults?['top'] as String? ?? '10') ?? 10);

    final bool showWeighted = argResults?['weighted'] as bool;
    final bool showAuthors = argResults?['authors'] as bool;
    final bool noFilter = argResults?['no-filter'] as bool;
    final bool showHeatmap = argResults?['heatmap'] as bool;
    final bool showTrend = argResults?['trend'] as bool;
    final bool showInsights = argResults?['insights'] as bool;
    final String? exportFormat = argResults?['export'] as String?;
    final String outputPath = argResults?['output'] as String;

    // 2. Determine Path
    String path = '.';
    if (argResults!.rest.isNotEmpty) {
      path = argResults!.rest.first;
    }

    final gitService = GitService();

    // 3. Validation
    final progress = logger.progress('Checking git installation');
    if (!await gitService.checkGitInstalled()) {
      progress.fail('Git is not installed or not in the system PATH.');
      return ExitCode.unavailable.code;
    }

    final gitRoot = await gitService.findGitRoot(path);
    if (gitRoot == null) {
      progress.fail("The directory '$path' is not a git repository.");
      return ExitCode.usage.code;
    }
    progress.complete('Git check passed');

    // 4. Load Config
    final loadProgress = logger.progress('Loading configuration');
    final config = await ConfigLoader.loadConfig(gitRoot);
    final gitIgnorePatterns = await FilterService.loadGitIgnore(gitRoot);
    loadProgress.complete();

    // 5. Analyze
    final filterService = FilterService(
      enableFiltering: !noFilter,
      customIgnorePatterns: [...?config?.ignorePatterns, ...gitIgnorePatterns],
    );

    final analyzer = Analyzer(filterService: filterService);
    final metricsEngine = MetricsEngine();

    try {
      final analyzeProgress = logger.progress(
        'Analyzing last $lastCommits commits in $gitRoot...',
      );
      final logRaw = await gitService.getRawLog(gitRoot, lastCommits);
      final fileHistories = analyzer.analyze(logRaw);
      final riskReports = metricsEngine.calculateRisk(fileHistories);
      analyzeProgress.complete('Analyzed ${fileHistories.length} files.');

      // Trend Analysis
      if (showTrend && lastCommits >= 50) {
        try {
          final prevLogRaw = await gitService.getRawLog(
            gitRoot,
            lastCommits * 2,
          );
          final prevHistories = analyzer.analyze(prevLogRaw);
          final prevReports = metricsEngine.calculateRisk(prevHistories);
          final recentScores = {for (var r in riskReports) r.filePath: r.score};
          final prevScores = {for (var r in prevReports) r.filePath: r.score};
          final trend = Visualizer.calculateStabilityTrend(
            recentScores,
            prevScores,
          );
          logger.info('Stability Trend: $trend');
        } catch (_) {}
      }

      // Directory Analysis
      final dirRisks = metricsEngine.calculateDirectoryRisk(riskReports);
      if (dirRisks.isNotEmpty) {
        logger.info('');
        logger.info(styleBold.wrap('📂 Directory Risk Summary:'));
        logger.info('--------------------------------------------------');
        dirRisks.forEach((dir, score) {
          final scoreStr = _colorizeScore(score);
          logger.info('  • ${padRight(dir, 35)} $scoreStr');
        });
      }

      // Output Results
      logger.info('');
      logger.info(styleBold.wrap('Top $topCount High-Risk Files:'));
      logger.info('--------------------------------------------------');

      var header =
          '${padRight('File', 40)}${padRight('Score', 10)}${padRight('Risk', 10)}${padRight('Changes', 10)}';
      if (showHeatmap) header += padRight('Heatmap', 25);
      if (showAuthors) header += padRight('Authors', 10);
      if (showWeighted) header += '  (Details)';
      logger.info(header);
      logger.info('--------------------------------------------------');

      for (var report in riskReports.take(topCount)) {
        final history = fileHistories.firstWhere(
          (h) => h.path == report.filePath,
        );
        String line = _formatReportLine(
          report,
          history,
          showHeatmap,
          showAuthors,
          showWeighted,
          logger,
        );
        logger.info(line);
      }

      // Insights
      if (showInsights) {
        _showInsights(fileHistories);
      }

      // Export
      if (exportFormat != null) {
        final exportProgress = logger.progress('Generating export(s)...');
        if (exportFormat == 'html' || exportFormat == 'both') {
          await Exporter.generateHtml(
            riskReports,
            fileHistories,
            '$outputPath.html',
          );
        }
        if (exportFormat == 'json' || exportFormat == 'both') {
          await Exporter.generateJson(
            riskReports,
            fileHistories,
            '$outputPath.json',
          );
        }
        exportProgress.complete('Export completed to $outputPath.*');
      }

      // Interactive Mode
      if (argResults?['interactive'] == true) {
        logger.info('');
        _runInteractiveMode(riskReports, fileHistories);
      }

      return ExitCode.success.code;
    } catch (e) {
      logger.err('Error during analysis: $e');
      return ExitCode.software.code;
    }
  }

  void _runInteractiveMode(
    List<RiskReport> reports,
    List<FileHistory> histories,
  ) {
    if (reports.isEmpty) return;

    final choices = reports.take(20).map((r) => r.filePath).toList();
    choices.add('Exit');

    while (true) {
      final choice = logger.chooseOne(
        'Select a file to view detailed history:',
        choices: choices,
      );

      if (choice == 'Exit') break;

      final history = histories.firstWhere((h) => h.path == choice);
      logger.info('');
      logger.info(styleBold.wrap('📄 File: $choice'));
      logger.info('Changes: ${history.changeCount}');

      final uniqueAuthors = history.commits.map((c) => c.authorEmail).toSet();
      logger.info('Authors: ${uniqueAuthors.join(', ')}');

      logger.info('Recent Commits:');
      for (var commit in history.commits.take(5)) {
        logger.info(
          '  ${commit.date.toString().substring(0, 10)} - ${commit.authorEmail}',
        );
      }
      logger.info('');
    }
  }

  String _formatReportLine(
    RiskReport report,
    FileHistory history,
    bool showHeatmap,
    bool showAuthors,
    bool showWeighted,
    Logger logger,
  ) {
    final scoreStr = _colorizeScore(report.score);
    final riskStr = _colorizeRisk(report.riskLevel);

    var line =
        '${padRight(truncate(report.filePath, 38), 40)}${padRight(scoreStr, 10 + (scoreStr.length - report.score.toString().length))}${padRight(riskStr, 10 + (riskStr.length - report.riskLevel.length))}${padRight(history.changeCount.toString(), 10)}';

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
      // Recalculate component scores (duplicated logic from MetricsEngine, ideal refactor: move to RiskReport)
      // For now, keep simple
      line += '  (Details)';
    }
    return line;
  }

  void _showInsights(List<FileHistory> fileHistories) {
    logger.info('');
    logger.info('═══════════════════════════════════════════════════');
    logger.info('📊 DEEP INSIGHTS');
    logger.info('═══════════════════════════════════════════════════');

    final insightsEngine = InsightsEngine();
    final coChangePatterns = insightsEngine.analyzeCoChange(fileHistories);

    if (coChangePatterns.isNotEmpty) {
      logger.info('');
      logger.info('🔗 Co-Change Patterns (Files that change together):');
      for (var pattern in coChangePatterns.take(10)) {
        final percentage = (pattern.coChangeRate * 100).toStringAsFixed(0);
        logger.info('  • ${truncate(pattern.file1, 35)}');
        logger.info('    ↔ ${truncate(pattern.file2, 35)}');
        logger.info(
          '    Co-changed $percentage% of the time (${pattern.coChangeCount} times)\n',
        );
      }
    }

    final knowledgeSilos = insightsEngine.findKnowledgeSilos(fileHistories);
    if (knowledgeSilos.isNotEmpty) {
      logger.info('');
      logger.info('⚠️  Knowledge Silos (High bus factor risk):');
      for (var silo in knowledgeSilos.take(10)) {
        logger.info('  • ${truncate(silo.filePath, 40)}');
        logger.info(
          '    ${silo.changeCount} changes by ONLY: ${silo.soleAuthor}',
        );
        logger.info('    ⚠️  If this person leaves, knowledge is lost!\n');
      }
    }
    logger.info('═══════════════════════════════════════════════════');
  }

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
    // Quick and dirty pad, assuming no ansi codes in input s for length check unless handled
    // But s might have ansi codes from colorize.
    // We need to strip ansi for length calc.
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
