import 'dart:io';
import 'package:args/args.dart';
import 'package:repo_analyzer/rea.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('last',
        abbr: 'l', defaultsTo: '50', help: 'Number of last commits to analyze')
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show usage information');

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

  // determine repository path
  // if a path argument is provided, use it. Otherwise default to current directory.
  String path = '.';
  if (argResults.rest.isNotEmpty) {
    path = argResults.rest.first;
  }

  final int lastCommits = int.tryParse(argResults['last'] as String) ?? 50;

  final gitService = GitService();
  final analyzer = Analyzer();

  //  validation of git installed
  if (!await gitService.checkGitInstalled()) {
    print('Error: Git is not installed or not in the system PATH.');
    exit(1);
  }

  final isGitRepo = await gitService.checkIsGitRepo(path);
  if (!isGitRepo) {
    print("Error: The directory '$path' is not a git repository.");
    print(
        'Please run REA from within a git repository or provide a path to one.');
    exit(1);
  }

  //  core analysis
  try {
    final log = await gitService.getLogStat(path, lastCommits);
    final fileCounts = analyzer.analyze(log);

    print('Analyzed last $lastCommits commits.');
    print('Total files changed: ${fileCounts.length}');
    print('');
    print('Top 5 Most Changed Files:');
    print('-------------------------');

    final sortedEntries = fileCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (var entry in sortedEntries.take(5)) {
      print('${entry.key}: ${entry.value}');
    }
  } catch (e) {
    print('Error analyzing repository: $e');
    exit(1);
  }
}
