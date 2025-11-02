#!/usr/bin/env python3
"""
Get Home Assistant configuration including available integrations and domains.

Usage:
    python3 ha_get_config.py

Requires HA_TOKEN environment variable to be set.
"""

import os
import sys
import json
import urllib.request
import urllib.error

HA_URL = "https://ha.cullen.rocks"

def get_config():
    """Fetch Home Assistant configuration."""
    token = os.environ.get("HA_TOKEN")
    if not token:
        print("Error: HA_TOKEN environment variable not set", file=sys.stderr)
        sys.exit(1)

    url = f"{HA_URL}/api/config"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req) as response:
            config = json.loads(response.read().decode())
            return config
    except urllib.error.HTTPError as e:
        print(f"HTTP Error {e.code}: {e.reason}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

def main():
    config = get_config()
    print(json.dumps(config, indent=2))

if __name__ == "__main__":
    main()
