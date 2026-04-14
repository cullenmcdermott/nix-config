#!/usr/bin/env python3
# /// script
# dependencies = [
#   "websockets",
# ]
# ///
"""
Search for Home Assistant dashboards by name or ID.

Uses the WebSocket API since Lovelace dashboard endpoints are not available via REST.

Usage:
    uv run ha_search_dashboards.py [search_pattern]

Examples:
    uv run ha_search_dashboards.py                    # List all dashboards
    uv run ha_search_dashboards.py "phone"            # Search for dashboards with "phone" in the name
    uv run ha_search_dashboards.py "firetab8hd"       # Search for specific dashboard

Requires HA_TOKEN environment variable to be set.
"""

import os
import sys
import json
import asyncio
import websockets

HA_WS_URL = "wss://ha.cullen.rocks/api/websocket"


async def ws_connect_and_auth():
    """Connect to HA WebSocket API and authenticate."""
    token = os.environ.get("HA_TOKEN")
    if not token:
        print("Error: HA_TOKEN environment variable not set", file=sys.stderr)
        sys.exit(1)

    websocket = await websockets.connect(HA_WS_URL)

    # Receive auth_required
    msg = json.loads(await websocket.recv())
    if msg.get("type") != "auth_required":
        print(f"Error: Expected auth_required, got {msg.get('type')}", file=sys.stderr)
        sys.exit(1)

    # Send auth
    await websocket.send(json.dumps({
        "type": "auth",
        "access_token": token
    }))

    # Receive auth response
    msg = json.loads(await websocket.recv())
    if msg.get("type") != "auth_ok":
        print(f"Error: Authentication failed: {msg}", file=sys.stderr)
        sys.exit(1)

    return websocket


async def ws_call(websocket, msg_id, msg_type, **kwargs):
    """Send a WebSocket command and return the result."""
    command = {"id": msg_id, "type": msg_type, **kwargs}
    await websocket.send(json.dumps(command))

    response = json.loads(await websocket.recv())
    if not response.get("success"):
        error = response.get("error", {})
        print(f"Error from {msg_type}: {error.get('message', 'Unknown error')}", file=sys.stderr)
        sys.exit(1)

    return response.get("result")


async def run(search_pattern=None):
    """List dashboards (optionally filtered) and fetch config for single matches."""
    websocket = await ws_connect_and_auth()
    msg_id = 1

    try:
        # List all dashboards
        dashboards = await ws_call(websocket, msg_id, "lovelace/dashboards/list")
        msg_id += 1

        if dashboards is None:
            dashboards = []

        # Filter by search pattern, preferring exact matches
        if search_pattern:
            pattern_lower = search_pattern.lower()

            # Check for exact match on any field first
            exact = [
                d for d in dashboards
                if pattern_lower in (
                    d.get("id", "").lower(),
                    d.get("title", "").lower(),
                    d.get("url_path", "").lower(),
                )
            ]
            if exact:
                dashboards = exact
            else:
                dashboards = [
                    d for d in dashboards
                    if pattern_lower in d.get("id", "").lower()
                    or pattern_lower in d.get("title", "").lower()
                    or pattern_lower in d.get("url_path", "").lower()
                ]

        if not dashboards:
            if search_pattern:
                print(f"No dashboards found matching '{search_pattern}'", file=sys.stderr)
            else:
                print("No dashboards found", file=sys.stderr)
            sys.exit(1)

        # Single match: fetch its full config
        if len(dashboards) == 1:
            dashboard = dashboards[0]
            url_path = dashboard.get("url_path")

            print(f"Found dashboard: {dashboard.get('title', 'Untitled')} (url_path: {url_path})")
            print("\nDashboard metadata:")
            print(json.dumps(dashboard, indent=2))

            if url_path:
                config = await ws_call(websocket, msg_id, "lovelace/config", url_path=url_path)
                msg_id += 1
                print(f"\n\nFull dashboard configuration:")
                print(json.dumps(config, indent=2))
        else:
            print(f"Found {len(dashboards)} dashboard(s):\n")
            for dashboard in dashboards:
                print(json.dumps(dashboard, indent=2))
                print()
    finally:
        await websocket.close()


def main():
    search_pattern = sys.argv[1] if len(sys.argv) > 1 else None
    asyncio.run(run(search_pattern))


if __name__ == "__main__":
    main()
