import 'package:repo_analyzer/src/commands/command_runner.dart';

Future<void> main(List<String> arguments) async {
  await ReaCommandRunner().run(arguments);
  // Exit code is handled by CommandRunner returning int, but main void is typical for simple apps
  // If we want to force exit code:
  // exit(await ReaCommandRunner().run(arguments));
  // But let's check if we want to explicitly exit.
  // The command runner catches exceptions and prints usage.
}
