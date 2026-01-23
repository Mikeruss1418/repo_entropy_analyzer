import 'dart:io';
import 'package:process_run/shell.dart';
import 'package:path/path.dart' as context;

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

  /// Checks if the given path is a git repository, climbing up if necessary.
  Future<String?> findGitRoot(String startPath) async {
    var dir = Directory(startPath);
    if (!await dir.exists()) return null;

    var currentPath = dir.absolute.path;
    while (true) {
      final gitPath = context.join(currentPath, '.git');
      if (await Directory(gitPath).exists() || await File(gitPath).exists()) {
        return currentPath;
      }

      final parent = Directory(currentPath).parent;
      if (parent.path == currentPath) {
        // Reached root
        return null;
      }
      currentPath = parent.path;
    }
  }

  /// Retrieves the git log with author and date info.
  Future<String> getRawLog(String path, int limit) async {
    try {
      // --no-merges: Excludes merge commits
      // --pretty=format:"%ae|%ad": Author Email | Author Date (ISO-like by default, or respecting --date)
      // --name-only: Show changed files
      final result = await runExecutableArguments('git', [
        'log',
        '--no-merges',
        '--pretty=format:COMMIT_START|%ae|%ad',
        '--date=iso',
        '--name-only',
        '-n',
        '$limit',
      ], workingDirectory: path);

      if (result.exitCode != 0) {
        throw Exception('Git command failed: ${result.stderr}');
      }
      return result.stdout.toString();
    } catch (e) {
      throw Exception('Failed to run git command: $e');
    }
  }
}
