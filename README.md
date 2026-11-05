# opencode config

My global [opencode](https://opencode.ai) configuration (`~/.config/opencode`).
It points opencode at a self-hosted **llama.cpp** server on my Tailscale network.

## Install on a new machine

```bash
# back up an existing config first, if there is one
[ -d ~/.config/opencode ] && mv ~/.config/opencode ~/.config/opencode.bak

git clone git@github.com:falkorichter/opencode-config.git ~/.config/opencode
```

Requirements:

- opencode (tested with v2.2.5)
- The machine must be on the same Tailscale tailnet, so it can reach `the llama-server host`
- `service.json` is **not** in this repo (it holds a local password). opencode creates it on first run if needed.

Update later with `git -C ~/.config/opencode pull`.

## Settings explained (`opencode.json`)

| Key | Value | Meaning |
|-----|-------|---------|
| `$schema` | `https://opencode.ai/config.json` | Enables autocomplete and validation in editors. |
| `model` | `v1000/Terathox-Coder/Qwen3.8-27B-MTP-GGUF:Q4_K_M` | Default model, in the format `<provider-id>/<model-id>`. |

### Provider `v1000`

| Key | Value | Meaning |
|-----|-------|---------|
| `npm` | `@ai-sdk/openai-compatible` | Talk to the server through the OpenAI-compatible API, which `llama-server` provides. |
| `name` | `v1000 (llama.cpp)` | Display name in the opencode UI. |
| `options.baseURL` | `__OPENCODE_BASE_URL__` | `llama-server` endpoint on host `v1000`, reached over Tailscale MagicDNS. |

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
