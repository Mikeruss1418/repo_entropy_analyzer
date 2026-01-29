# Installation & Distribution Guide

Repo Entropy Analyzer (REA) is a standalone CLI tool. Users do **not** need Dart installed to use it if you distribute it correctly. Here are the three best ways to share it with other teams (Python, JS, Go devs, etc.).

## 1. Standalone Binaries (Recommended)
The easiest way is to provide a single executable file that users can download.

### How to Build
Run these commands on your machine (or CI/CD pipeline) to generate the binary:
```bash
# For the OS you are currently running on:
dart compile exe bin/main.dart -o build/rea.exe  # Windows
dart compile exe bin/main.dart -o build/rea      # Mac/Linux
```

### How Users Install
1.  Download the `rea.exe` (Windows) or `rea` (Mac/Linux) file.
2.  Add it to their System `PATH` (or just run it directly).
3.  **Run**: `rea analyze`

*Tip: You can host these binaries on the "Releases" page of your GitHub repository.*

---

## 2. Docker (Universal / CI/CD)
This is the best option for CI pipelines (Jenkins, GitHub Actions) or users who don't want to mess with system paths.

### 1. Build the Image
```bash
docker build -t rea .
```

### 2. Run Analysis
You mount the target directory to `/repo` inside the container:

```bash
# Analyze the current directory
docker run --rm -v "$(pwd):/repo" rea analyze

# Analyze with arguments
docker run --rm -v "$(pwd):/repo" rea analyze --insights
```
*(Windows PowerShell: use `${PWD}` instead of `$(pwd)`)*

---

## 3. NPM Wrapper (Optional)
If your team is mostly React/Node developers, they prefer `npm install`. You can wrap the binary in a simple package.

1.  Create a `package.json` with a `bin` entry pointing to a downloaded binary.
2.  Users run: `npx repo-analyzer analyze`

---

## 4. Dart Pub (For Flutter/Dart Teams)
If the user already has Dart installed:
```bash
dart pub global activate --source git https://github.com/Start-Up-Ferry/repo_analyzer.git
```
