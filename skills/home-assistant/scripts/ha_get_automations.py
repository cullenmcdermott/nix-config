#!/usr/bin/env python3
"""
Retrieve all automations from Home Assistant with their configurations.

Usage:
    python3 ha_get_automations.py [search_term]

Examples:
    python3 ha_get_automations.py                    # All automations
    python3 ha_get_automations.py motion             # Automations with 'motion' in name
    python3 ha_get_automations.py light              # Automations with 'light' in name

Requires HA_TOKEN environment variable to be set.
"""

import os
import sys
import json
import urllib.request
import urllib.error

HA_URL = "https://ha.cullen.rocks"

def get_automations(search_term=None):
    """Fetch all automation entities."""
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

            # Filter to automation entities
            automations = [e for e in entities if e["entity_id"].startswith("automation.")]

            # Filter by search term if provided
            if search_term:
                search_term = search_term.lower()
                automations = [
                    a for a in automations
                    if search_term in a["entity_id"].lower() or
                       search_term in a.get("attributes", {}).get("friendly_name", "").lower()
                ]

            return automations
    except urllib.error.HTTPError as e:
        print(f"HTTP Error {e.code}: {e.reason}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

def main():
    search_term = sys.argv[1] if len(sys.argv) > 1 else None
    automations = get_automations(search_term)
    print(json.dumps(automations, indent=2))

if __name__ == "__main__":
    main()
