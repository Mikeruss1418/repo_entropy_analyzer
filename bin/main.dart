import 'package:repo_analyzer/git_reader.dart';
import 'package:repo_analyzer/metrics.dart';

Future<void> main() async {
  final log = await getGitLog(lastCommits: 50);
  final fileCounts = countFileChanges(log);

  final int topcount = 10;

  print('File Change Frequency (Top $topcount)');
  final top5 = fileCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  for (var entry in top5.take(topcount)) {
    print('${entry.key}: ${entry.value} changes');
  }
}
