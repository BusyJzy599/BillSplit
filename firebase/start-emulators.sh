#!/bin/bash
cd "$(dirname "$0")/.."
echo "Starting Firebase emulators..."
echo "  Firestore: http://localhost:8080"
echo "  Auth:      http://localhost:9099"
echo "  UI:        http://localhost:4000"
echo ""
firebase emulators:start --project demo-billsplit
