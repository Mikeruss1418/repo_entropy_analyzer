import 'dart:io';
import 'package:process_run/shell.dart';

class GitService {
  /// Checks if git is installed and accessible in the system path.
  Future<bool> checkGitInstalled() async {
    try {
      await runExecutableArguments('git', ['--version']);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Checks if the given path is a git repository.
  Future<bool> checkIsGitRepo(String path) async {
    // Check if directory exists first
    final dir = Directory(path);
    if (!await dir.exists()) {
      return false;
    }

    try {
      final result = await runExecutableArguments(
        'git',
        ['rev-parse', '--is-inside-work-tree'],
        workingDirectory: path,
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Retrieves the git log with stats.
  Future<String> getLogStat(String path, int limit) async {
    try {
      final result = await runExecutableArguments(
        'git',
        ['log', '--stat', '-n', '$limit'],
        workingDirectory: path,
      );

      if (result.exitCode != 0) {
        throw Exception('Git command failed: ${result.stderr}');
      }
      return result.stdout.toString();
    } catch (e) {
      throw Exception('Failed to run git command: $e');
    }
  }
}
