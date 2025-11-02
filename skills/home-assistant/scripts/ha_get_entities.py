#!/usr/bin/env python3
"""
Retrieve entities from Home Assistant.

Usage:
    python3 ha_get_entities.py [domain]

Examples:
    python3 ha_get_entities.py light
    python3 ha_get_entities.py sensor
    python3 ha_get_entities.py          # All entities

Requires HA_TOKEN environment variable to be set.
"""

import os
import sys
import json
import urllib.request
import urllib.error

HA_URL = "https://ha.cullen.rocks"

def get_entities(domain=None):
    """Fetch entities from Home Assistant, optionally filtered by domain."""
    token = os.environ.get("HA_TOKEN")
    if not token:
        print("Error: HA_TOKEN environment variable not set", file=sys.stderr)
        sys.exit(1)

    url = f"{HA_URL}/api/states"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req) as response:
            entities = json.loads(response.read().decode())

            if domain:
                entities = [e for e in entities if e["entity_id"].startswith(f"{domain}.")]

            return entities
    except urllib.error.HTTPError as e:
        print(f"HTTP Error {e.code}: {e.reason}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

def main():
    domain = sys.argv[1] if len(sys.argv) > 1 else None
    entities = get_entities(domain)
    print(json.dumps(entities, indent=2))

if __name__ == "__main__":
    main()
