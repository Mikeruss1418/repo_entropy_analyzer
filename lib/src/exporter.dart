import 'dart:io';
import 'dart:convert';
import 'metrics_engine.dart';

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

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>REA Report - ${DateTime.now().toString().split('.')[0]}</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      padding: 20px;
      min-height: 100vh;
    }
    .container {
      max-width: 1200px;
      margin: 0 auto;
      background: white;
      border-radius: 12px;
      box-shadow: 0 20px 60px rgba(0,0,0,0.3);
      overflow: hidden;
    }
    header {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      padding: 30px;
      text-align: center;
    }
    h1 { font-size: 2.5em; margin-bottom: 10px; }
    .subtitle { opacity: 0.9; font-size: 1.1em; }
    .stats {
      display: flex;
      justify-content: space-around;
      padding: 20px;
      background: #f8f9fa;
      border-bottom: 2px solid #e9ecef;
    }
    .stat { text-align: center; }
    .stat-value { font-size: 2em; font-weight: bold; color: #667eea; }
    .stat-label { color: #6c757d; margin-top: 5px; }
    table {
      width: 100%;
      border-collapse: collapse;
    }
    th {
      background: #343a40;
      color: white;
      padding: 15px;
      text-align: left;
      cursor: pointer;
      user-select: none;
    }
    th:hover { background: #495057; }
    td { padding: 12px 15px; border-bottom: 1px solid #dee2e6; }
    tr:hover { background: #f8f9fa; }
    .risk-badge {
      padding: 4px 12px;
      border-radius: 12px;
      font-weight: bold;
      font-size: 0.85em;
      display: inline-block;
    }
    .risk-critical { background: #dc3545; color: white; }
    .risk-high { background: #ffc107; color: #000; }
    .risk-medium { background: #17a2b8; color: white; }
    .risk-low { background: #28a745; color: white; }
    footer {
      text-align: center;
      padding: 20px;
      color: #6c757d;
      font-size: 0.9em;
    }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <h1>📊 Repo Entropy Analyzer</h1>
      <div class="subtitle">Risk Assessment Report</div>
    </header>
    
    <div class="stats">
      <div class="stat">
        <div class="stat-value">${reports.length}</div>
        <div class="stat-label">Total Files</div>
      </div>
      <div class="stat">
        <div class="stat-value">${reports.where((r) => r.score >= 80).length}</div>
        <div class="stat-label">Critical Risk</div>
      </div>
      <div class="stat">
        <div class="stat-value">${reports.where((r) => r.score >= 60 && r.score < 80).length}</div>
        <div class="stat-label">High Risk</div>
      </div>
    </div>
    
    <table id="reportTable">
      <thead>
        <tr>
          <th onclick="sortTable(0)">File Path ▼</th>
          <th onclick="sortTable(1)">Score ▼</th>
          <th onclick="sortTable(2)">Risk Level ▼</th>
          <th onclick="sortTable(3)">Changes ▼</th>
          <th onclick="sortTable(4)">Authors ▼</th>
        </tr>
      </thead>
      <tbody>
        $rows
      </tbody>
    </table>
    
    <footer>
      Generated on ${DateTime.now().toString().split('.')[0]} by REA v0.0.2
    </footer>
  </div>
  
  <script>
    function sortTable(col) {
      const table = document.getElementById('reportTable');
      const tbody = table.tBodies[0];
      const rows = Array.from(tbody.rows);
      
      rows.sort((a, b) => {
        let aVal = a.cells[col].textContent.trim();
        let bVal = b.cells[col].textContent.trim();
        
        // Try numeric comparison
        const aNum = parseFloat(aVal);
        const bNum = parseFloat(bVal);
        if (!isNaN(aNum) && !isNaN(bNum)) {
          return bNum - aNum;
        }
        
        // String comparison
        return aVal.localeCompare(bVal);
      });
      
      rows.forEach(row => tbody.appendChild(row));
    }
  </script>
</body>
</html>
''';
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
