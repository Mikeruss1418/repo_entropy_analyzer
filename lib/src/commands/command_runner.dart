import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'analyze_command.dart';
import 'diff_command.dart';

class ReaCommandRunner extends CommandRunner<int> {
  final Logger logger;

  ReaCommandRunner({Logger? logger})
    : logger = logger ?? Logger(),
      super('rea', 'Repo Entropy Analyzer - Find hotspots in your code.') {
    // Add subcommands
    addCommand(AnalyzeCommand(this.logger));
    addCommand(DiffCommand(this.logger));

    // Global flags
    argParser.addFlag(
      'version',
      abbr: 'v',
      negatable: false,
      help: 'Print the current version.',
    );

    argParser.addFlag(
      'verbose',
      help: 'Enable verbose logging.',
      negatable: false,
    );
  }

  @override
  Future<int> run(Iterable<String> args) async {
    try {
      final topLevelResults = parse(args);
      if (topLevelResults['verbose'] == true) {
        logger.level = Level.verbose;
      }

      if (topLevelResults['version'] == true) {
        logger.info('Repo Entropy Analyzer v0.0.5');
        return ExitCode.success.code;
      }

      // Default to 'analyze' if no command is specified and args look like options or path
      if (topLevelResults.command == null &&
          args.isNotEmpty &&
          !args.contains('--help') &&
          !args.contains('-h')) {
        // Treat as implicit analyze command
        // This is a bit tricky with CommandRunner.
        // Strategy: If first arg is not a command, prepend 'analyze'
        final commandNames = commands.keys.toList();
        if (!commandNames.contains(args.first)) {
          return await run(['analyze', ...args]);
        }
      }

      // If no args (or just flags), default to analyze
      if (topLevelResults.command == null &&
          (args.isEmpty || args.every((a) => a.startsWith('-')))) {
        return await run(['analyze', ...args]);
      }

      return await super.run(args) ?? ExitCode.success.code;
    } on UsageException catch (e) {
      logger.err(e.message);
      logger.info(e.usage);
      return ExitCode.usage.code;
    } catch (e) {
      logger.err(e.toString());
      return ExitCode.software.code;
    }
  }
}
