#!/usr/bin/env python3
# /// script
# dependencies = [
#   "homeassistant-api",
# ]
# ///
"""
Retrieve all automations from Home Assistant with their configurations.

Usage:
    uv run ha_get_automations.py [search_term]

Examples:
    uv run ha_get_automations.py                    # All automations
    uv run ha_get_automations.py motion             # Automations with 'motion' in name
    uv run ha_get_automations.py light              # Automations with 'light' in name

Requires HA_TOKEN environment variable to be set.
"""

import os
import sys
import json
from homeassistant_api import Client

HA_URL = "https://ha.cullen.rocks/api"

def get_automations(search_term=None):
    """Fetch all automation entities."""
    token = os.environ.get("HA_TOKEN")
    if not token:
        print("Error: HA_TOKEN environment variable not set", file=sys.stderr)
        sys.exit(1)

    try:
        with Client(HA_URL, token) as client:
            entities = client.get_states()

            # Filter to automation entities
            automations = [
                entity.model_dump(mode='json') for entity in entities
                if entity.entity_id.startswith("automation.")
            ]

            # Filter by search term if provided
            if search_term:
                search_term = search_term.lower()
                automations = [
                    a for a in automations
                    if search_term in a["entity_id"].lower() or
                       search_term in a.get("attributes", {}).get("friendly_name", "").lower()
                ]

            return automations
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

def main():
    search_term = sys.argv[1] if len(sys.argv) > 1 else None
    automations = get_automations(search_term)
    print(json.dumps(automations, indent=2))

if __name__ == "__main__":
    main()
