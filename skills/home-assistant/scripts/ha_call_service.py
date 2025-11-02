#!/usr/bin/env python3
"""
Call a Home Assistant service.

Usage:
    python3 ha_call_service.py <domain> <service> <service_data_json>

Example:
    python3 ha_call_service.py light turn_on '{"entity_id": "light.living_room", "brightness": 255}'

Requires HA_TOKEN environment variable to be set.
"""

import os
import sys
import json
import urllib.request
import urllib.error

HA_URL = "https://ha.cullen.rocks"

def call_service(domain, service, service_data):
    """Call a Home Assistant service."""
    token = os.environ.get("HA_TOKEN")
    if not token:
        print("Error: HA_TOKEN environment variable not set", file=sys.stderr)
        sys.exit(1)

    url = f"{HA_URL}/api/services/{domain}/{service}"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    try:
        data = json.dumps(service_data).encode('utf-8')
        req = urllib.request.Request(url, data=data, headers=headers, method='POST')
        with urllib.request.urlopen(req) as response:
            result = json.loads(response.read().decode())
            return result
    except urllib.error.HTTPError as e:
        print(f"HTTP Error {e.code}: {e.reason}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

def main():
    if len(sys.argv) < 4:
        print("Usage: ha_call_service.py <domain> <service> <service_data_json>", file=sys.stderr)
        sys.exit(1)

    domain = sys.argv[1]
    service = sys.argv[2]

    try:
        service_data = json.loads(sys.argv[3])
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in service_data: {e}", file=sys.stderr)
        sys.exit(1)

    result = call_service(domain, service, service_data)
    print(json.dumps(result, indent=2))

if __name__ == "__main__":
    main()
