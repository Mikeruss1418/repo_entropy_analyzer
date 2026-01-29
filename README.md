# Repo Entropy Analyzer (REA)

A powerful CLI tool designed to identify "hotspots" in your git repository—files that change frequently, are touched by many authors, or are becoming risk vectors.

## 🚀 Features

-   **Entropy Analysis**: Claculate "Risk Scores" (0-100) based on churn, recency, and complexity (bus factor).
-   **Directory Analysis**: Automatically aggregate risk scores across modules and folders to find architecture hotspots.
-   **Interactive Mode**: Explore file history, author stats, and risk details directly in the terminal.
-   **Diff Safety Check**: Compare your current branch against `main` or `staging` to catch risky changes before they merge.
-   **Deep Insights**: Detect "Co-Change Patterns" (tight coupling) and "Knowledge Silos" (bus factor risk).
-   **Visualization**: Beautiful ASCII heatmaps and stability trend indicators.
-   **Export**: Generate detailed HTML and JSON reports.

## 📦 Installation

### Global Activation
You can activate the package globally to use the `rea` command anywhere:

```bash
dart pub global activate --source path .
# Then run:
rea --help
# Discalimer after making the changes, Delete the .dart_tool and activate it again
```

### Local Usage
Or run it directly from the source:

```bash
dart run bin/main.dart --help
```

## 📖 Usage Cheat Sheet

### 🔍 Analysis
| Command | Description |
| :--- | :--- |
| `rea analyze` | Run standard analysis (default: last 50 commits, top 10 files). |
| `rea analyze -l 100` | Analyze the last **100** commits. |
| `rea analyze --verbose` | Analyze **ALL** commits and show **ALL** files. |
| `rea analyze --interactive` | **[NEW]** Interactive mode to select and view specific file histories. |
| `rea analyze --heatmap` | Show ASCII visual heatbars for risk scores. |
| `rea analyze --insights` | Enable deep insights (Co-change patterns & Knowledge silos). |
| `rea analyze --trend` | Show stability trend vs previous timeframe. |

### 🛡️ Diff / Safety Check
| Command | Description |
| :--- | :--- |
| `rea diff` | Compare current changes against `staging` (default). |
| `rea diff main` | Compare current changes against `main` branch. |
| `rea diff develop` | Compare current changes against `develop` branch. |

### 📊 Reports
| Command | Description |
| :--- | :--- |
| `rea analyze --export html` | Generate an HTML report (`rea_report.html`). |
| `rea analyze --export json` | Generate a JSON data file (`rea_report.json`). |
| `rea analyze --export both` | Generate both HTML and JSON. |
| `rea analyze -o my_report` | Save as `my_report.html`/`my_report.json` (custom filename). |

### 🚩 Key Flags & Options
| Flag | Short | Description |
| :--- | :--- | :--- |
| `--help` | `-h` | Show help usage. |
| `--version` | `-v` | Show tool version. |
| `--weighted` | | Show detailed score breakdown (Base + Recency + Bus Factor). |
| `--authors` | | Show count of unique authors per file. |
| `--no-filter` | | **Include** generated files (mocks, freezed, etc.) and ignored files. |
| `--color` | | Toggle colored output (default: true). |

## ⚙️ Configuration
You can optionally create a `.rea.yaml` file in your project root to customize default behavior.

```yaml
# .rea.yaml
last_commits: 100
ignore_patterns:
  - "**/*.g.dart"
  - "assets/**"
  - "**/generated/**"
colors: true
```

**Note**: REA also automatically respects your project's `.gitignore` rules.

## 🛠️ Development

To run tests:
```bash
dart test
```

## 📄 License
MIT
