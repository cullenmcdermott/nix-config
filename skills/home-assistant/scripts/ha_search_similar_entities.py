#!/usr/bin/env python3
"""
Search for entities similar to a given pattern or domain.
Useful for finding examples when building automations.

Usage:
    python3 ha_search_similar_entities.py <pattern>

Examples:
    python3 ha_search_similar_entities.py "bedroom light"
    python3 ha_search_similar_entities.py "motion"
    python3 ha_search_similar_entities.py "temperature"

Requires HA_TOKEN environment variable to be set.
"""

import os
import sys
import json
import urllib.request
import urllib.error

HA_URL = "https://ha.cullen.rocks"

def search_entities(pattern):
    """Search for entities matching a pattern."""
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

            pattern_lower = pattern.lower()
            matching = []

            for entity in entities:
                entity_id = entity["entity_id"].lower()
                friendly_name = entity.get("attributes", {}).get("friendly_name", "").lower()

                if pattern_lower in entity_id or pattern_lower in friendly_name:
                    matching.append({
                        "entity_id": entity["entity_id"],
                        "friendly_name": entity.get("attributes", {}).get("friendly_name", ""),
                        "state": entity["state"],
                        "domain": entity["entity_id"].split(".")[0],
                        "attributes": entity.get("attributes", {})
                    })

            return matching
    except urllib.error.HTTPError as e:
        print(f"HTTP Error {e.code}: {e.reason}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

def main():
    if len(sys.argv) < 2:
        print("Usage: ha_search_similar_entities.py <pattern>", file=sys.stderr)
        sys.exit(1)

    pattern = sys.argv[1]
    matches = search_entities(pattern)

    if matches:
        print(json.dumps(matches, indent=2))
    else:
        print(f"No entities found matching '{pattern}'", file=sys.stderr)

if __name__ == "__main__":
    main()
