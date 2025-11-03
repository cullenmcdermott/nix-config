#!/usr/bin/env python3
# /// script
# dependencies = [
#   "websockets",
# ]
# ///
"""
List automation traces from Home Assistant.

Usage:
    uv run ha_list_traces.py [automation_id]

Examples:
    uv run ha_list_traces.py                                    # All automation traces
    uv run ha_list_traces.py automation.notify_on_door_open     # Traces for specific automation

Requires HA_TOKEN environment variable to be set.
"""

import os
import sys
import json
import asyncio
import websockets

HA_URL = "wss://ha.cullen.rocks/api/websocket"

async def list_traces(automation_id=None):
    """List automation traces, optionally filtered by automation_id."""
    token = os.environ.get("HA_TOKEN")
    if not token:
        print("Error: HA_TOKEN environment variable not set", file=sys.stderr)
        sys.exit(1)

    try:
        async with websockets.connect(HA_URL) as websocket:
            # Step 1: Receive auth_required message
            msg = await websocket.recv()
            auth_msg = json.loads(msg)

            if auth_msg.get("type") != "auth_required":
                print(f"Error: Expected auth_required, got {auth_msg.get('type')}", file=sys.stderr)
                sys.exit(1)

            # Step 2: Send auth message
            await websocket.send(json.dumps({
                "type": "auth",
                "access_token": token
            }))

            # Step 3: Receive auth response
            msg = await websocket.recv()
            auth_result = json.loads(msg)

            if auth_result.get("type") != "auth_ok":
                print(f"Error: Authentication failed: {auth_result}", file=sys.stderr)
                sys.exit(1)

            # Step 4: Send trace/list command
            command = {
                "id": 1,
                "type": "trace/list",
                "domain": "automation"
            }

            if automation_id:
                # Strip "automation." prefix if present
                item_id = automation_id.replace("automation.", "")
                command["item_id"] = item_id

            await websocket.send(json.dumps(command))

            # Step 5: Receive response
            msg = await websocket.recv()
            response = json.loads(msg)

            if not response.get("success"):
                error = response.get("error", {})
                print(f"Error: {error.get('message', 'Unknown error')}", file=sys.stderr)
                sys.exit(1)

            result = response.get("result", {})

            if not result:
                if automation_id:
                    print(f"No traces found for automation: {automation_id}")
                else:
                    print("No traces found")
                return []

            # Format trace data for readability
            formatted_traces = []
            for trace in result:
                item_id = trace.get("item_id")
                formatted_traces.append({
                    "automation_id": f"automation.{item_id}" if item_id else "unknown",
                    "run_id": trace.get("run_id"),
                    "timestamp": trace.get("timestamp", {}).get("start"),
                    "state": trace.get("state"),
                    "script_execution": trace.get("script_execution"),
                    "last_step": trace.get("last_step"),
                    "error": trace.get("error")
                })

            # Sort by timestamp (most recent first)
            formatted_traces.sort(key=lambda x: x.get("timestamp", ""), reverse=True)

            return formatted_traces

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)

def main():
    automation_id = sys.argv[1] if len(sys.argv) > 1 else None
    traces = asyncio.run(list_traces(automation_id))

    if traces:
        print(json.dumps(traces, indent=2))

if __name__ == "__main__":
    main()
