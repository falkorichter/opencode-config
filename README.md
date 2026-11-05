# opencode config

My global [opencode](https://opencode.ai) configuration (`~/.config/opencode`).
It points opencode at a self-hosted **llama.cpp** server on my Tailscale network.

## Install on a new machine

```bash
# back up an existing config first, if there is one
[ -d ~/.config/opencode ] && mv ~/.config/opencode ~/.config/opencode.bak

git clone git@github.com:falkorichter/opencode-config.git ~/.config/opencode
cd ~/.config/opencode && ./setup.sh
```

Requirements:

- opencode (tested with v2.2.5)
- Network access to the llama-server machine (in my case over Tailscale)
- `service.json` is **not** in this repo (it holds a local password). opencode creates it on first run. See [About `service.json`](#about-servicejson).

Update later with `git -C ~/.config/opencode pull && ~/.config/opencode/setup.sh`.

## Server URL and `setup.sh`

The llama-server URL is machine-specific, so it's not in this repo. Instead:

- `opencode.json.template` is the config committed to git, with the placeholder `__OPENCODE_BASE_URL__` in place of the URL.
- `setup.sh` generates `opencode.json` from the template. It takes the URL from, in this order:
  1. the first argument: `./setup.sh http://myhost:8081/v1`
  2. `OPENCODE_BASE_URL` in `.env` (see `.env.example`)
  3. an interactive prompt, which offers to save your answer to `.env`
- `opencode.json` and `.env` are in `.gitignore`. If `opencode.json` already exists and would change, the script backs it up to `opencode.json.bak` first.

To change a setting (models, limits, ...), edit `opencode.json.template`, not `opencode.json`, then rerun `./setup.sh`.
Otherwise the change gets overwritten the next time the script runs.

## About `service.json`

`~/.config/opencode/service.json` configures opencode's **background service**. It is excluded via `.gitignore`.

opencode v2 runs a local background server (default port 49374 for the `latest` channel). The terminal UI and other
clients connect to it over HTTP instead of running everything in one process. Those connections use HTTP basic auth
with the username `opencode` and the `password` from this file, so other local processes or users can't control the
opencode session through that port.

The file can contain these keys: `password`, `hostname`, `port`, `cors`, `env`, `disabled`, `remote`. Mine only
contains `password`.

A related file, `~/.local/state/opencode/service.json`, is the runtime record of the running service (process ID,
URL, version and password). Clients read it to find the server. That's state, not config.

Notes:

- It's a per-machine secret. Don't commit it, especially since this repo is public.
- It doesn't need to be copied to a new machine. opencode generates it on first run.
- Machines don't need matching passwords. Each one only protects its own local service. You'd only share it if
  a client on one machine should connect to the opencode service on another (`remote`/`hostname`), which this setup
  doesn't do. The connection to `llama-server` on v1000 doesn't use this file.

This file isn't officially documented. The details above come from reading the opencode 2.2.5 binary.

## Settings explained (`opencode.json.template`)

| Key | Value | Meaning |
|-----|-------|---------|
| `$schema` | `https://opencode.ai/config.json` | Enables autocomplete and validation in editors. |
| `model` | `v1000/Terathox-Coder/Qwen3.8-27B-MTP-GGUF:Q4_K_M` | Default model, in the format `<provider-id>/<model-id>`. |

### Provider `v1000`

| Key | Value | Meaning |
|-----|-------|---------|
| `npm` | `@ai-sdk/openai-compatible` | Talk to the server through the OpenAI-compatible API, which `llama-server` provides. |
| `name` | `v1000 (llama.cpp)` | Display name in the opencode UI. |
| `options.baseURL` | `__OPENCODE_BASE_URL__` | `llama-server` endpoint, filled in by `setup.sh`. Usually ends in `/v1`. |

### Model `Terathox-Coder/Qwen3.8-27B-MTP-GGUF:Q4_K_M`

The model key has to match the model name that `llama-server` reports.

| Key | Value | Meaning |
|-----|-------|---------|
| `name` | `Qwen3.8 27B Coder (v1000)` | Display name. |
| `tool_call` | `true` | The model supports tool/function calling, which opencode needs to edit files and run commands. |
| `attachment` | `false` | The model can't take attachments, so opencode won't send it images or files. |
| `modalities.input` | `["text"]` | Text-only input. |
| `modalities.output` | `["text"]` | Text-only output. |
| `limit.context` | `80000` | Context window in tokens. Keep this at or below the server's `--ctx-size`. |
| `limit.output` | `16384` | Maximum tokens per response. |

### Why text-only?

`llama-server` runs this model without a multimodal projector (`--mmproj`). Any request that contains an
image fails with:

```
Error: image input is not supported - hint: if this is unexpected, you may need to provide the mmproj
```

Setting `attachment: false` and `modalities.input: ["text"]` stops opencode from sending images to this model.
To use images, run a vision-capable model with `llama-server --mmproj <mmproj-file>.gguf` and add `"image"` to `modalities.input`.
