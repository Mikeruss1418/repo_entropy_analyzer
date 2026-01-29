const String htmlReportTemplate = r'''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>REA Report - {{GENERATED_AT}}</title>
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
        <div class="stat-value">{{TOTAL_FILES}}</div>
        <div class="stat-label">Total Files</div>
      </div>
      <div class="stat">
        <div class="stat-value">{{CRITICAL_COUNT}}</div>
        <div class="stat-label">Critical Risk</div>
      </div>
      <div class="stat">
        <div class="stat-value">{{HIGH_COUNT}}</div>
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
        {{ROWS}}
      </tbody>
    </table>
    
    <footer>
      Generated on {{GENERATED_AT}} by REA {{VERSION}}
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
