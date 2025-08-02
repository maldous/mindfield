#!/usr/bin/env sh
python3 - <<'EOF'
import urllib.request, sys
resp = urllib.request.urlopen("http://localhost:3000/health")
sys.exit(0 if resp.status == 200 else 1)
EOF
