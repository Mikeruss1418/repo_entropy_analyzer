import 'package:process_run/process_run.dart';

Future<String> getGitLog({int lastCommits = 50}) async {
  try {
    // runExecutableArguments is more reliable across platforms
    final result = await runExecutableArguments(
      'git',
      ['log', '--stat', '-n', '$lastCommits'],
    );

    if (result.exitCode != 0) {
      throw Exception('Git command failed: ${result.stderr}');
    }

    return result.stdout.toString();
  } catch (e) {
    throw Exception('Failed to run git command: $e');
  }
}
