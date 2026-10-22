# Lab 1: Freestyle Job

Freestyle jobs are configured in the UI, so there is no code file. These are the exact settings used.

## Job settings

- **Item name:** `01-first-freestyle-job`
- **Type:** Freestyle project

## Build step: Execute shell

```bash
echo "=== Running First Jenkins Build ==="
date
hostname
pwd
echo "Hello from Jenkins Build #$BUILD_NUMBER" > build_artifact.txt
ls -la
```

## Post-build action: Archive the artifacts

- **Files to archive:** `build_artifact.txt`

## What to observe

1. Build Now, then open the build and click **Console Output**.
2. `pwd` prints the workspace path Jenkins created on disk.
3. After the archive step is added, the build page shows **Build Artifacts** with a downloadable file.

## Why this matters

Everything above lives only in Jenkins. If someone edits or deletes the shell box, there is no history to roll back to. That is the main reason teams move to Pipeline as Code (Lab 2).
