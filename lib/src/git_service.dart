import 'dart:io';
import 'dart:convert';
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

  /// Retrieves the current branch name.
  Future<String> getCurrentBranch(String path) async {
    try {
      final result = await runExecutableArguments('git', [
        'rev-parse',
        '--abbrev-ref',
        'HEAD',
      ], workingDirectory: path);
      return result.stdout.toString().trim();
    } catch (e) {
      throw Exception('Failed to get current branch: $e');
    }
  }

  /// Retrieves files changed between HEAD and the target branch.
  /// Also includes uncommitted changes if local changes exist.
  Future<List<String>> getChangedFiles(String path, String target) async {
    try {
      // 1. Files changed in commits between target..HEAD
      // 2. Files changed in working directory (uncommitted)
      // "git diff --name-only <target>" covers both if we are on HEAD.

      final result = await runExecutableArguments('git', [
        'diff',
        '--name-only',
        target,
      ], workingDirectory: path);

      if (result.exitCode != 0) {
        throw Exception('Git diff failed: ${result.stderr}');
      }

      return result.stdout
          .toString()
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
    } catch (e) {
      throw Exception('Failed to get diff: $e');
    }
  }

  /// Retrieves the git log with author and date info.
  @Deprecated('Use getRawLogStream for better memory usage')
  Future<String> getRawLog(String path, int limit) async {
    try {
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

  /// Retrieves the git log as a stream of lines.
  Stream<String> getRawLogStream(String path, int limit) async* {
    try {
      final process = await Process.start('git', [
        'log',
        '--no-merges',
        '--pretty=format:COMMIT_START|%ae|%ad',
        '--date=iso',
        '--name-only',
        '-n',
        '$limit',
      ], workingDirectory: path);

      // We need to handle stderr as well, ideally
      // For now, let's yield lines from stdout
      // Using system encoding usually handles utf8
      yield* process.stdout
          .transform(SystemEncoding().decoder)
          .transform(const LineSplitter());

      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        // We could yield an error or throw, but since it's a stream, throwing might end it.
        // Let's assume emptiness if failed or throw.
        // throw Exception('Git process failed with exit code $exitCode');
      }
    } catch (e) {
      throw Exception('Failed to start git process: $e');
    }
  }
}
