#!/usr/bin/env python3
"""
Get all available Home Assistant services with their descriptions and fields.

Usage:
    python3 ha_get_services.py [domain]

Examples:
    python3 ha_get_services.py           # All services
    python3 ha_get_services.py light     # Just light services
    python3 ha_get_services.py climate   # Just climate services

Requires HA_TOKEN environment variable to be set.
"""

import os
import sys
import json
import urllib.request
import urllib.error

HA_URL = "https://ha.cullen.rocks"

def get_services(domain=None):
    """Fetch available services, optionally filtered by domain."""
    token = os.environ.get("HA_TOKEN")
    if not token:
        print("Error: HA_TOKEN environment variable not set", file=sys.stderr)
        sys.exit(1)

    url = f"{HA_URL}/api/services"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req) as response:
            services_list = json.loads(response.read().decode())

            # Convert list of {domain, services} to dict
            services_dict = {item["domain"]: item["services"] for item in services_list}

            if domain:
                if domain in services_dict:
                    return {domain: services_dict[domain]}
                else:
                    return {}

            return services_dict
    except urllib.error.HTTPError as e:
        print(f"HTTP Error {e.code}: {e.reason}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

def main():
    domain = sys.argv[1] if len(sys.argv) > 1 else None
    services = get_services(domain)
    print(json.dumps(services, indent=2))

if __name__ == "__main__":
    main()
