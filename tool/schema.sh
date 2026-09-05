#!/usr/bin/env bash
# Dump the current Drift schema and regenerate the migration-test helpers.
# Run after every schemaVersion bump. Dumped files are immutable history.
set -euo pipefail
cd "$(dirname "$0")/.."
dart run drift_dev schema dump lib/data/db/app_database.dart drift_schemas/
dart run drift_dev schema generate drift_schemas/ test/data/schema/
echo "schema dumped to drift_schemas/ and verifier regenerated in test/data/schema/"
