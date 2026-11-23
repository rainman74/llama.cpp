# Windows example scripts — llama.cpp on a 10 GB RTX 3080

Production-tested launcher scripts for `llama-server` / `llama-cli`, tuned for a single
**RTX 3080 (10 GB VRAM, sm_86)**, 32 GB RAM and Windows. Every value in these scripts was
measured on that machine — nothing is a guess.

All servers listen on **port 9931** with the OpenAI-compatible API on `/v1` and the model alias
**`llama-home`**, so clients (OpenClaw, the built-in WebUI, any OpenAI SDK) only need:

```
base_url = http://<host>:9931/v1
model    = llama-home
```

---

## 1. Folder layout

```
windows-examples\
├── llserver_Gemma-4-12B.cmd              server  Gemma 4 12B uncensored
├── llserver_Gemma-4-E4B.cmd              server  Gemma 4 E4B   ← agent default
├── llserver_Gemma-4-E2B.cmd              server  Gemma 4 E2B
├── llserver_Inkling-2-Mini-IQ1_S.cmd     server  Inkling 2 Mini IQ1_S
├── llserver_Inkling-2-Mini-UD-IQ2_XXS.cmd  server  Inkling 2 Mini IQ2_XXS
├── llstart_*.cmd                         interactive llama-cli twins of the servers
├── llstop.cmd                            stop all llama-server.exe
├── llcheck.cmd                           RAM / VRAM report
├── llhelp.cmd                            dump --help to llama-*.txt
├── lltest.cmd                            API smoke test (one question, prints answer)
└── models\
    └── chat-template-gemma-4-exb.jinja       patched template, ExB models only (see § 5)
```

**Model files are not part of this repository.** The scripts resolve everything relative to
their own location (`set "BASE=%~dp0"`), so they must live **next to** `llama-server.exe` and the
`models\` folder — i.e. in the runtime folder, not in the source tree.

---

## 2. Requirements

| | |
|---|---|
| GPU | NVIDIA RTX 3080, 10 GB VRAM (any Ampere or newer with ≥ 10 GB works) |
| RAM | 32 GB |
| Build | **Unsloth `b12649-mix-c7059d6`** (23 Nov 2026) or newer from [unslothai/llama.cpp](https://github.com/unslothai/llama.cpp/releases) |
| Disk | ~46 GB for the model files below |

> **Inkling 2 Mini: use the Unsloth build.** Earlier mainline versions fail with
> `unknown model architecture: 'inkling2'`. On 23 Nov 2026 Unsloth re-released every quant so

---

## 3. Script catalogue

### Server scripts

Start `llama-server.exe` in the background (`start /b`), verify model / projector / drafter
exist, print a banner, then open `http://localhost:9931`.

| Script | Model | ctx | Speculative | Notes |
|---|---|---|---|---|
| `llserver_Gemma-4-12B.cmd` | 12B uncensored `Q4_K_S` | 32768 | MTP | best quality at short context; 32k is the MTP limit |
| **`llserver_Gemma-4-E4B.cmd`** | E4B `Q4_K_P` | 131072 | MTP | **agent default** — patched template, thinking budget 256 |
| `llserver_Gemma-4-E2B.cmd` | E2B `Q8_K_P` | 131072 | MTP | same patch and budget; fastest Gemma, but too small for agent work |
| `llserver_Inkling-2-Mini-IQ1_S.cmd` | Inkling `IQ1_S` | 131072 | DSpark | 1 slot, KV in VRAM; vision + audio |
| `llserver_Inkling-2-Mini-UD-IQ2_XXS.cmd` | Inkling `IQ2_XXS` | 131072 | DSpark | KV in **RAM** (`--no-kv-offload`), 2-bit experts |

### CLI scripts

`llstart_<model>.cmd` are the interactive twins of the servers: same model and flags, but
`llama-cli.exe` in the foreground with `-lv 3` and a German system prompt (`SYSPROMPT`). They set
no alias and no port — the CLI does not need them.

| Script | Model | ctx | Speculative |
|---|---|---|---|
| `llstart_Gemma-4-12B.cmd` | 12B uncensored `Q4_K_S` | 32768 | MTP |
| `llstart_Gemma-4-E4B.cmd` | E4B `Q4_K_P` | 131072 | MTP (patched template, budget 256) |
| `llstart_Gemma-4-E2B.cmd` | E2B `Q8_K_P` | 131072 | MTP (patched template, budget 256) |
| `llstart_Inkling-2-Mini-IQ1_S.cmd` | Inkling `IQ1_S` | 131072 | DSpark |
| `llstart_Inkling-2-Mini-UD-IQ2_XXS.cmd` | Inkling `IQ2_XXS` | 131072 | DSpark |

All scripts pass `--spec-draft-n-max 2`. Four alternating runs on `IQ2_XXS` at 131072 measured
**19.2 t/s with 58 % acceptance** against 18.6 t/s and 45.5 % with `n-max 3` — plus a smaller draft
buffer, which matters on a 10 GB card. Unsloth's guide recommends the same value.

**131072 context with a Q8_0 KV cache** works since the Unsloth build `b12649` (23 Nov 2026). Before
that fix, `q4_0`/`q8_0` caches used *more* VRAM than `f16` (banded attention was missing for those
types). Measured with `IQ2_XXS`, `-ctk/-ctv q8_0`, `--kv-offload`: it loads with 246 MiB left over.

### Helper scripts

| Script | Purpose |
|---|---|
| `llstop.cmd` | Kills `llama-server.exe` by image name (`tasklist`, language independent), checks port 9931, prints GPU memory |
| `llcheck.cmd` | Process RAM plus `nvidia-smi` totals (total / used / free) |
| `llhelp.cmd` | Writes `llama-server.txt` / `llama-cli.txt` help dumps from the binaries next to the script |
| `lltest.cmd` | API smoke test: asks one question against `/v1/chat/completions`, prints answer and speed |

### Common variables

Every script keeps its values in the first block, so a variant is a two-line edit:

| Variable | Meaning |
|---|---|
| `MODELNAME` | Display name in the banner |
| `CTX` | **Total** context; per slot = `CTX / PARALLEL`, rounded up to a multiple of 256 |
| `PARALLEL` | Slots. More slots = fairness, not throughput |
| `UBATCH` | Most important lever: sizes the compute buffer, decides whether weights and the MoE cache stay in VRAM |
| `KVFLAG` | `--kv-offload` (KV in VRAM, fast) / `--no-kv-offload` (KV in RAM, saves VRAM) |
| `KVTYPE` | KV cache type, `q8_0` everywhere |
| `LOADMODE` | `none` = no mmap, model fully in RAM (+6 % decode, ~40 s startup) |
| `SPEC_TYPE` | `draft-mtp` (Gemma), `draft-dspark` (Inkling) |
| `DRAFT` | Drafter path; empty falls back to `--spec-type none` |
| `THINK_BUDGET` | `--reasoning-budget` in tokens. The banner prints `0 Token (reasoning off)` when `REASONING=off` |
| `REASONING` | `auto` / `off` |
| `CHAT_TPL` | Patched chat template, only in the Gemma scripts (E4B, E2B) |
| `VERBOSITY` | `-lv`; 1 = errors only, 2 = + warnings, 3 = + info (needed to see the fit lines) |

---

## 4. Ports and aliases

One server at a time. `llstop.cmd` before starting another model — 10 GB of VRAM do not fit two.

```
alias   llama-home
port    9931
API     http://<host>:9931/v1   (OpenAI compatible; /health, /props, /slots, /metrics)
WebUI   http://<host>:9931
```

---

## 5. The chat template (`models\chat-template-gemma-4-exb.jinja`, ExB only)

**Why it exists.** The Gemma 4 templates shipped inside the GGUF render the system prompt like this:

```jinja
{%- if messages[0]['role'] in ['system', 'developer'] -%}
    {{- messages[0]['content'] | trim -}}
```

`trim` expects a string. Clients that send the system prompt as a **content-parts list**
(`[{"type":"text","text":"…"}]`, the OpenAI format) get the **Python repr** of the list instead:

```
<|turn>system
<|think|>[{'type': 'text', 'text': 'SYS-PARTS'}]<turn|>
```

With a 70k-token agent bootstrap this turns the whole instruction block into one data dump — the
model then quotes the bootstrap instead of answering.

**The patch** handles string *and* list content (plus image / audio / video parts) and is wired in
via `--chat-template-file` in the two Gemma scripts (E4B and E2B):

```jinja
{%- if messages[0]['content'] is string -%}
    {{- messages[0]['content'] | trim -}}
{%- else -%}
    {%- for item in messages[0]['content'] -%}
        {%- if item['type'] == 'text' -%}{{- item['text'] | trim -}}
        {%- elif item['type'] == 'image' -%}{{- '\n\n<|image|>\n\n' -}}
        {%- elif item['type'] == 'audio' -%}{{- '<|audio|>' -}}
        {%- elif item['type'] == 'video' -%}{{- '\n\n<|video|>\n\n' -}}
        {%- endif -%}
    {%- endfor -%}
{%- endif -%}
```

**Inkling and the 12B do not need this.** The Inkling template branches on `message.content is
string` and iterates parts (including images). The 12B fine-tune ships a newer template (17,466
chars) that already handles `is string` / `is sequence`. Replacing either would override the model's
own formatting — the 12B template, for example, emits `<|think|>` followed by a newline.

The Gemma scripts also run `REASONING=auto` with `THINK_BUDGET=256`: with reasoning off, a
small model follows the dominant context pattern instead of the instruction.

---

## 6. Model files

All files belong in `models\`. Sizes are decimal GB. Every link was verified (HTTP 200).

### Inkling 2 Mini — [unsloth/Inkling-2-Mini-GGUF](https://huggingface.co/unsloth/Inkling-2-Mini-GGUF)

| File | Size | Download |
|---|---|---|
| `Inkling-2-Mini-UD-IQ1_S.gguf` | 7.76 GB | [download](https://huggingface.co/unsloth/Inkling-2-Mini-GGUF/resolve/main/Inkling-2-Mini-UD-IQ1_S.gguf) |
| `Inkling-2-Mini-UD-IQ2_XXS.gguf` | 8.49 GB | [download](https://huggingface.co/unsloth/Inkling-2-Mini-GGUF/resolve/main/Inkling-2-Mini-UD-IQ2_XXS.gguf) |
| `mmproj-F16.gguf` (vision + audio) | 0.64 GB | [download](https://huggingface.co/unsloth/Inkling-2-Mini-GGUF/resolve/main/mmproj-F16.gguf) |
| `dspark-Inkling-2-Mini-Q8_0.gguf` (drafter) | 0.40 GB | [download](https://huggingface.co/unsloth/Inkling-2-Mini-GGUF/resolve/main/dspark-Inkling-2-Mini-Q8_0.gguf) |

> Use `mmproj-F16.gguf`. Do **not** use `mmproj-BF16.gguf` from that repository — it belongs to a
> different model family.

**`mmproj-F32.gguf`** (1.27 GB) is the same projector at double precision — twice the size for no
measurable quality gain, so `F16` is the default here.
**`imatrix_unsloth.gguf`** (45 MB) is Unsloth's **importance matrix**, not a model: calibration data
that `llama-quantize --imatrix` uses when *creating* a quant. The server and the CLI ignore it, and
colibri refuses it outright. It is only useful if you build your own quant from a larger file.

### Gemma 4 12B uncensored — [zaakirio/gemma-4-12b-it-uncensored-GGUF](https://huggingface.co/zaakirio/gemma-4-12b-it-uncensored-GGUF)

| File | Size | Download |
|---|---|---|
| `gemma-4-12b-it-uncensored-Q4_K_S.gguf` | 7.02 GB | [download](https://huggingface.co/zaakirio/gemma-4-12b-it-uncensored-GGUF/resolve/main/gemma-4-12b-it-uncensored-Q4_K_S.gguf) |
| `mmproj-gemma-4-12B-it-bf16.gguf` (vision) | 0.18 GB | [download](https://huggingface.co/zaakirio/gemma-4-12b-it-uncensored-GGUF/resolve/main/mmproj-gemma-4-12B-it-bf16.gguf) |
| `mtp-gemma-4-12b-it-uncensored.gguf` (drafter, matching pair) | 0.47 GB | [download](https://huggingface.co/zaakirio/gemma-4-12b-it-uncensored-GGUF/resolve/main/mtp-gemma-4-12b-it-uncensored.gguf) |

### Gemma 4 E4B uncensored — [HauhauCS/Gemma-4-E4B-Uncensored-HauhauCS-Aggressive](https://huggingface.co/HauhauCS/Gemma-4-E4B-Uncensored-HauhauCS-Aggressive)

| File | Size | Download |
|---|---|---|
| `Gemma-4-E4B-Uncensored-HauhauCS-Aggressive-Q4_K_P.gguf` | 5.37 GB | [download](https://huggingface.co/HauhauCS/Gemma-4-E4B-Uncensored-HauhauCS-Aggressive/resolve/main/Gemma-4-E4B-Uncensored-HauhauCS-Aggressive-Q4_K_P.gguf) |
| `mmproj-Gemma-4-E4B-Uncensored-HauhauCS-Aggressive-f16.gguf` (vision + audio) | 0.99 GB | [download](https://huggingface.co/HauhauCS/Gemma-4-E4B-Uncensored-HauhauCS-Aggressive/resolve/main/mmproj-Gemma-4-E4B-Uncensored-HauhauCS-Aggressive-f16.gguf) |
| `mtp-gemma-4-E4B-it-Q8_0.gguf` (drafter) | 0.10 GB | [download](https://huggingface.co/unsloth/gemma-4-E4B-it-GGUF/resolve/main/MTP/mtp-gemma-4-E4B-it-Q8_0.gguf) |

### Gemma 4 E2B uncensored — [HauhauCS/Gemma-4-E2B-Uncensored-HauhauCS-Aggressive](https://huggingface.co/HauhauCS/Gemma-4-E2B-Uncensored-HauhauCS-Aggressive)

| File | Size | Download |
|---|---|---|
| `Gemma-4-E2B-Uncensored-HauhauCS-Aggressive-Q8_K_P.gguf` | 5.04 GB | [download](https://huggingface.co/HauhauCS/Gemma-4-E2B-Uncensored-HauhauCS-Aggressive/resolve/main/Gemma-4-E2B-Uncensored-HauhauCS-Aggressive-Q8_K_P.gguf) |
| `mmproj-Gemma-4-E2B-Uncensored-HauhauCS-Aggressive-f16.gguf` (vision + audio) | 0.99 GB | [download](https://huggingface.co/HauhauCS/Gemma-4-E2B-Uncensored-HauhauCS-Aggressive/resolve/main/mmproj-Gemma-4-E2B-Uncensored-HauhauCS-Aggressive-f16.gguf) |
| `mtp-gemma-4-E2B-it-Q8_0.gguf` (drafter) | 0.10 GB | [download](https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/MTP/mtp-gemma-4-E2B-it-Q8_0.gguf) |

**The MTP drafters are made from the base `-it` models, not from the fine-tunes.** They still work
with the uncensored GGUFs — acceptance drops from ~65 % to ~30–50 %, which is far better than no
speculative decoding at all.

---

## 7. Measured numbers (RTX 3080, 76k-token prompt)

| Configuration | Prefill | Decode | VRAM free |
|---|---|---|---|
| E4B `Q4_K_P`, 131k, KV in VRAM, MTP | 6 500 t/s | 85–110 t/s | 2 100 MiB |
| 12B `Q4_K_S`, 131k, **KV in RAM**, MTP | 1 290 t/s | 21 t/s | 587 MiB |
| E2B `Q8_K_P`, 131k, KV in VRAM, MTP | 8 800 t/s | 86–130 t/s | 4 000 MiB |
| Inkling `IQ1_S`, 131k, KV in VRAM, DSpark | 110–185 t/s | 19–25 t/s | 2 500 MiB |

Reading: a 76k-token agent bootstrap costs **11 s** of prefill on an E4B and **12–15 minutes** on
Inkling. The 12B cannot hold 131k in VRAM on this card — KV in RAM makes it ~5× slower than the E4B.

---

## 8. Known issues

- **`#32771`** (upstream, open): speculative decoding can leave accepted-but-unseen tokens in the
  slot cache when generation stops inside a draft. Rare, but the reason the agent scripts keep
  `THINK_BUDGET` small.
- **FP8 KV cache (`f8_e4m3`) buys nothing on Ampere** — no FP8 tensor cores; `q8_0` has the same
  size and runs through a conversion path anyway.
- **`--spec-draft-p-min > 0` silently disables DSpark** (no confidence head).
- **The chat template bug is fixed here**, not upstream — rerun the patch if you swap the GGUF.
