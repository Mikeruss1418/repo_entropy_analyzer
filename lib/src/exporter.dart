import 'dart:io';
import 'dart:convert';
import 'metrics_engine.dart';
import 'templates/html_template.dart';

class Exporter {
  /// Generates HTML report
  static Future<void> generateHtml(
    List<RiskReport> reports,
    List<FileHistory> histories,
    String outputPath,
  ) async {
    final html = _buildHtmlReport(reports, histories);
    await File(outputPath).writeAsString(html);
  }

  /// Generates JSON report
  static Future<void> generateJson(
    List<RiskReport> reports,
    List<FileHistory> histories,
    String outputPath,
  ) async {
    final data = reports.map((report) {
      final history = histories.firstWhere((h) => h.path == report.filePath);
      final uniqueAuthors = history.commits.map((c) => c.authorEmail).toSet();

      return {
        'file': report.filePath,
        'score': report.score,
        'risk_level': report.riskLevel,
        'change_count': history.changeCount,
        'unique_authors': uniqueAuthors.length,
        'authors': uniqueAuthors.toList(),
        'first_change': history.commits.isNotEmpty
            ? history.commits.last.date.toIso8601String()
            : null,
        'last_change': history.commits.isNotEmpty
            ? history.commits.first.date.toIso8601String()
            : null,
      };
    }).toList();

    final json = JsonEncoder.withIndent('  ').convert({
      'generated_at': DateTime.now().toIso8601String(),
      'total_files': reports.length,
      'files': data,
    });

    await File(outputPath).writeAsString(json);
  }

  static String _buildHtmlReport(
    List<RiskReport> reports,
    List<FileHistory> histories,
  ) {
    final rows = reports
        .map((report) {
          final history = histories.firstWhere(
            (h) => h.path == report.filePath,
          );
          final uniqueAuthors = history.commits
              .map((c) => c.authorEmail)
              .toSet()
              .length;
          final riskClass = report.riskLevel.toLowerCase();

          return '''
        <tr class="risk-$riskClass">
          <td>${_escapeHtml(report.filePath)}</td>
          <td>${report.score}</td>
          <td class="risk-badge risk-$riskClass">${report.riskLevel}</td>
          <td>${history.changeCount}</td>
          <td>$uniqueAuthors</td>
        </tr>
      ''';
        })
        .join('\n');

    final generatedAt = DateTime.now().toString().split('.')[0];
    final totalFiles = reports.length;
    final criticalCount = reports.where((r) => r.score >= 80).length;
    final highCount = reports
        .where((r) => r.score >= 60 && r.score < 80)
        .length;

    return htmlReportTemplate
        .replaceAll('{{GENERATED_AT}}', generatedAt)
        .replaceAll('{{TOTAL_FILES}}', totalFiles.toString())
        .replaceAll('{{CRITICAL_COUNT}}', criticalCount.toString())
        .replaceAll('{{HIGH_COUNT}}', highCount.toString())
        .replaceAll('{{ROWS}}', rows)
        .replaceAll('{{VERSION}}', 'v0.0.5'); // Updated version
  }

  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
