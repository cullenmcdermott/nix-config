---
name: homelab-models
description: Run homelab-served models (GLM on the Sparks, later anything on llm.cullen.rocks) as implementation workers through omp. Use when the user asks for GLM, a local model, or a homelab model as a worker; load the delegation skill too for the handoff rules.
---

# Homelab models through omp

`omp` (oh-my-pi) runs the local tier: models served on the homelab Sparks,
listed live from the endpoint's `/v1/models`. Follow the delegation skill's
handoff rules (one bounded task per run, task text in a file, parent verifies).

```sh
omp --list-models homelab   # what's served now; also refreshes omp's model cache
omp -p --no-session --no-skills --no-lsp --tools read,bash,edit,write \
  --model homelab/glm-5.3-flash --cwd "$PWD" @"$agent_task_dir/task.md"
```

- The tool list keeps the worker lean (about 9K prompt tokens instead of 26K)
  and leaves out omp's `task` tool, so it can't delegate further.
- At most 3 omp workers at once: the server runs 4 sequences and shares its
  KV cache with other users. Parallel writers each get their own worktree.
- Run it inside the parent's sandbox. The endpoint and omp's state dirs are
  already allowed; never run omp with the sandbox disabled to get it working.
- "No API key" or an unknown model usually means a cold model cache: run
  `omp --list-models homelab` once and retry. `HOMELAB_LLM_API_KEY` comes
  from `~/.env`.
- Local models are weaker than the strong tiers: give exact files and
  acceptance commands, and review the diff before accepting it.
