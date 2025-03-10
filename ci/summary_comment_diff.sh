#!/bin/bash
set -euxo pipefail

OLD_OUTPUT=$1
NEW_OUTPUT=$2

# Your script to generate a diff between old and new build statistics
# Example:
echo "Build Statistics Diff:"
diff $OLD_OUTPUT $NEW_OUTPUT
