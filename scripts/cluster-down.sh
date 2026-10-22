#!/usr/bin/env bash
# Delete the Step 6 kind cluster.
set -euo pipefail
kind delete cluster --name stack-it-yourself
