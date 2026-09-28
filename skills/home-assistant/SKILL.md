---
name: home-assistant
description: Work with the user's Home Assistant instance (ha.cullen.rocks) — look up entities, states, services, and config entries; write or fix automations, scripts, and Lovelace dashboards; and debug why an automation did or didn't run using its execution traces. Use for any Home Assistant question or YAML task, even when the user just names a device, room, or automation.
---

# Home Assistant

Ground every answer in the live instance: look up the real entity IDs, service
fields, and existing automations before writing YAML. Guessed entity IDs and
service parameters are the most common way HA configs silently fail.

If Home Assistant MCP tools are available in the session, they cover the same
queries — use whichever is present. Otherwise use the scripts below.

## Scripts

In `scripts/` next to this file (installed at
`~/.claude/skills/home-assistant/scripts/`). Run with `uv run <path>`; each
declares its own dependencies. All need `HA_TOKEN` in the environment (a
long-lived access token) and print JSON.

| Script | Args | Use for |
|---|---|---|
| `ha_search_similar_entities.py` | `<pattern>` | Find entities by id or friendly name — start here |
| `ha_get_entities.py` | `[domain]` | List entities, optionally one domain |
| `ha_get_state.py` | `<entity_id>` | Current state + attributes |
| `ha_get_services.py` | `[domain]` | Services and their fields |
| `ha_get_config_entries.py` | `[domain]` | `config_entry_id`s for integrations |
| `ha_get_config.py` | | Version, location, loaded components |
| `ha_get_automations.py` | `[search]` | Automation configs — use similar ones as templates |
| `ha_search_dashboards.py` | `[pattern]` | Find dashboards (WebSocket API) |
| `ha_trace_summary.py` | `<automation_id>` | Success/failure rates, timings, common errors |
| `ha_list_traces.py` | `[automation_id]` | Recent runs with run IDs and status |
| `ha_get_trace.py` | `<automation_id> <run_id>` | Step-by-step trace of one run |

Trace scripts take the automation's numeric `id` attribute (e.g.
`1761430536701`, from `ha_get_automations.py` or the entity's attributes), not
the `automation.xxx` entity ID.

## Writing YAML

- Use current syntax: top-level `triggers:` / `conditions:` / `actions:`, each
  trigger keyed by `trigger: state` (not `platform:`), and `action:` for
  service calls (not `service:`). Match the style of the user's existing
  automations when they differ.
- Always set `alias`, `description`, and an explicit `mode`.
- Verify every entity ID and service field against the instance before
  presenting the YAML.
- Telegram goes through `telegram_bot.send_message` with a `config_entry_id`
  in `data` (get it from `ha_get_config_entries.py telegram_bot`), not a
  `notify.*` service.

## Applying changes

If you're working inside the HA config repo and it has its own instructions
(CLAUDE.md, Makefile targets, validation hooks), follow those. Otherwise
hand the user copy-paste YAML and say where it goes: Settings → Automations &
Scenes → Create automation → ⋮ → Edit in YAML for automations; the dashboard's Raw configuration
editor for Lovelace; `configuration.yaml` plus a restart for integrations.

## Debugging an automation

1. Find it and its numeric id: `ha_get_automations.py <name>`.
2. `ha_get_state.py automation.<name>` — is it on, and when did it last trigger?
3. `ha_trace_summary.py <id>`, then `ha_list_traces.py <id>` to pick a failing
   or suspicious run, then `ha_get_trace.py <id> <run_id>`.
4. The trace shows which trigger fired, each condition's result, and where
   execution stopped. If it never triggered, check the trigger entities' actual
   states and attribute values with `ha_get_state.py`.
5. Explain the cause from the trace evidence, then give the corrected YAML.
