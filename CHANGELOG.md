
## 0.0.4
- Added Phase 3: Diff Analysis
    - Feature comparison with target branch
    - by default compares with staging branch
    - rea diff == default cmd{diff with branch name 'staging'}
    - rea diff <branch_name> == cmd{diff with branch name <branch_name>}

## 0.0.3
- Added Phase 2: Metrics Calculation
    - by default analyzes last 50 commits
    - shows top 10 most changed files default
    - shows total files changed
    - shows entropy calcutaion
    
    - use dart run bin/main.dart -h to know about the cmds if running locally
    - use rea -h to know about the cmds if installed globally


## 0.0.2
- Added Phase 1: Core Analysis
    - by default analyzes last 50 commits
    - shows top 5 most changed files
    - shows total files changed
    - shows entropy
    
    - can pass number of last commits to analyze using --last option


