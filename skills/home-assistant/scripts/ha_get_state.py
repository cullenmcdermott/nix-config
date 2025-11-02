#!/usr/bin/env python3
"""
Get the state of a specific Home Assistant entity.

Usage:
    python3 ha_get_state.py <entity_id>

Example:
    python3 ha_get_state.py light.living_room

Requires HA_TOKEN environment variable to be set.
"""

import os
import sys
import json
import urllib.request
import urllib.error

HA_URL = "https://ha.cullen.rocks"

def get_state(entity_id):
    """Fetch the state of a specific entity."""
    token = os.environ.get("HA_TOKEN")
    if not token:
        print("Error: HA_TOKEN environment variable not set", file=sys.stderr)
        sys.exit(1)

    url = f"{HA_URL}/api/states/{entity_id}"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req) as response:
            state = json.loads(response.read().decode())
            return state
    except urllib.error.HTTPError as e:
        if e.code == 404:
            print(f"Error: Entity '{entity_id}' not found", file=sys.stderr)
        else:
            print(f"HTTP Error {e.code}: {e.reason}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

def main():
    if len(sys.argv) < 2:
        print("Usage: ha_get_state.py <entity_id>", file=sys.stderr)
        sys.exit(1)

    entity_id = sys.argv[1]
    state = get_state(entity_id)
    print(json.dumps(state, indent=2))

if __name__ == "__main__":
    main()
