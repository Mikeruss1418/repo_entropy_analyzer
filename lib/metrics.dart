Map<String, int> countFileChanges(String gitLog) {
  final fileChangeCount = <String, int>{};
  final lines = gitLog.split('\n');

  for (var line in lines) {
    line = line.trim();
    // Example: ignore commit messages, look for "file | lines changed"
    if (line.contains('|')) {
      final fileName = line.split('|')[0].trim();
      fileChangeCount[fileName] = (fileChangeCount[fileName] ?? 0) + 1;
    }
  }

  return fileChangeCount;
}
