# LocalAI Model Guide - RX 6800/6900 XT (16GB VRAM)

**Date:** 2025-11-02
**GPU:** AMD Radeon RX 6800/6900 XT (Navi 21)
**VRAM:** ~16GB
**Current Issue:** Models not loading (RPC/backend failures)

---

## Your Installed Models

### Text Generation Models (GGUF)

| Model | File Size | Est. VRAM | Parameters | Use Case |
|-------|-----------|-----------|------------|----------|
| **Qwen3-30B-A3B-Q3_K_M** | 14GB | ~14-15GB | 30B | Largest, best quality, fills VRAM |
| **gpt-oss-20b-mxfp4** | 12GB | ~12-13GB | 20B | Good quality, efficient quantization |
| **llama-3.1-8b-instruct** | 4.6GB | ~5-6GB | 8B | Fast, good for chat, leaves room for other tasks |
| **mistral-7b-instruct** | 4.1GB | ~4-5GB | 7B | Fast, efficient, instruction-tuned |
| **localai-functioncall-qwen2.5-7b** | 4.4GB | ~4-5GB | 7B | Function calling, tool use |
| **minicpm-v-4_5-Q4_K_M** | 4.7GB | ~5-6GB | ~4B | Vision model (with mmproj) |
| **galatolo-Q4_K** | 4.1GB | ~4-5GB | ? | Unknown model |
| **HuggingFaceTB_SmolLM3-3B** | 1.8GB | ~2-3GB | 3B | Smallest, fastest, great for testing |

### Utility Models

| Model | File Size | Est. VRAM | Use Case |
|-------|-----------|-----------|----------|
| **granite-embedding-107m** | 211MB | ~300MB | Text embeddings, RAG |
| **jina-reranker-v1-tiny** | 65MB | ~100MB | Reranking search results |
| **minicpm-v-4_5-mmproj** | 1.1GB | ~1.5GB | Vision projector (pair with minicpm) |

---

## VRAM Usage Strategy

### You Can Use ONE of These at a Time:

**Option 1: Maximum Quality**
- Qwen3-30B (14GB) - **Fills your entire VRAM**
- Best quality responses
- Slower generation

**Option 2: Fast & Efficient**
- Mistral-7B or LLaMA-3.1-8B (~5-6GB)
- Still excellent quality
- Faster generation
- **Leaves ~10GB free for multitasking**

**Option 3: Speed Demon**
- SmolLM3-3B (2-3GB)
- Very fast responses
- Good for simple tasks
- **Leaves ~13GB free**

### Why Models Load One at a Time

**GPU memory works differently than RAM:**
- Loading a model = loading entire model into VRAM
- Model stays in VRAM until explicitly unloaded
- Your 16GB is shared across all GPU tasks (desktop, browser, AI)
- LocalAI **automatically unloads** previous model when loading new one

**This is normal and expected!**

---

## Current Problem: RPC Backend Failures

### Error Messages Seen:
```
rpc error: code = Unknown desc = unimplemented
failed to load model with internal loader
failed to read system backends
```

### Root Cause:
The `latest-aio-gpu-hipblas` image's HIP/ROCm backend is not properly initialized for your Navi 21 GPU.

### Why It's Failing:
1. **Backend mismatch**: The prebuilt backends may not support Navi 21 properly
2. **GFX version**: Set to 10.3.0 (correct for Navi 21), but backend still failing
3. **Missing system backends**: `/usr/share/localai/backends` not found
4. **RPC communication broken**: gRPC between LocalAI and llama.cpp backend failing

---

## Solution: Rebuild with Proper Configuration

### Approach 1: Use CPU Backend (Temporary Fix)

**Pros:**
- Will work immediately
- No GPU driver issues
- Can test all models

**Cons:**
- MUCH slower (10-50x slower)
- No GPU acceleration

**How to Enable:**
Stop using AIO image, use base LocalAI with CPU-only llama.cpp

---

### Approach 2: Fix ROCm Backend (Best Solution)

**Steps:**
1. Pull a different LocalAI image with better ROCm support
2. Manually build llama.cpp with HIP support
3. Configure LocalAI to use the correct backend

**This will:**
- Enable full GPU acceleration
- Support all your GGUF models
- Work with your 16GB VRAM properly

---

## Model Recommendations by Use Case

### General Chat & Assistant
**Best:** LLaMA-3.1-8B or Mistral-7B
- Fast enough for real-time chat
- High quality responses
- Leaves VRAM for other tasks

### Maximum Quality (When You Have Time)
**Best:** Qwen3-30B
- Highest quality in your collection
- Use for complex tasks, coding, analysis
- Worth the slower speed

### Quick Tasks & Testing
**Best:** SmolLM3-3B
- Lightning fast
- Good for simple questions
- Testing new prompts

### Function Calling / Tool Use
**Best:** localai-functioncall-qwen2.5-7b
- Specialized for API calls, function execution
- Structured outputs

### Vision Tasks (Images)
**Best:** MiniCPM-V-4.5
- Understands images
- Requires both .gguf + mmproj files

---

## LiteLLM vs LocalAI

You have **both** systems. Here's when to use each:

### Use LiteLLM When:
✅ You want Claude Sonnet 4.5 (cloud API)
✅ You want Claude Haiku 4.5 (cloud API)
✅ You want to mix local + cloud models
✅ Big-AGI integration (works great)

### Use LocalAI When:
✅ 100% offline/local inference
✅ GPU acceleration (when fixed)
✅ Custom model fine-tuning
✅ Full control over models

### Current Reality:
**LiteLLM is working perfectly** - it proxies both LocalAI models + Claude APIs

**LocalAI backend is broken** - needs rebuild

---

## Next Steps (Rebuild Plan)

### Step 1: Backup Current Setup
```bash
# Stop container
docker stop local-ai

# Backup volumes
docker run --rm -v localai_models:/data -v $(pwd):/backup alpine \
  tar -czf /backup/localai-models-backup.tar.gz /data
```

### Step 2: Try Different Image
```yaml
services:
  local-ai:
    image: localai/localai:latest-gpu-hipblas  # Remove 'aio'
    # Or try: localai/localai:latest-rocm
    # ... rest of config
```

### Step 3: Manual Backend Build
If prebuilt images fail, we'll:
1. Build llama.cpp with HIP support locally
2. Mount it into LocalAI container
3. Configure LocalAI to use custom backend

### Step 4: Test Each Model
Verify each model loads and generates text

---

## Workaround: Use LiteLLM (Currently Working)

**In Big-AGI:**
- Add LiteLLM endpoint: `http://localhost:4000/v1`
- API Key: `sk-^XZX64qiUwZo*S`
- You get access to:
  - All LocalAI models (proxied)
  - Claude Sonnet 4.5 (cloud)
  - Claude Haiku 4.5 (cloud)

**This works RIGHT NOW** while we fix LocalAI!

---

## Understanding Model Naming

### In LocalAI API:
- `Qwen3-30B-A3B-Q3_K_M` (exact filename)
- Case-sensitive

### In LiteLLM:
- `qwen3-30b` (simplified alias)
- Defined in [litellm_config.yaml](file:///home/ssjlox/AI/litellm_config.yaml)

### In Big-AGI:
- Uses whatever the API returns
- LocalAI: shows full filename
- LiteLLM: shows alias

---

## VRAM Monitoring Commands

### Check What's Using Your GPU:
```bash
# If you have radeontop
radeontop

# Check VRAM via sysfs
cat /sys/class/drm/card0/device/mem_info_vram_used
cat /sys/class/drm/card0/device/mem_info_vram_total
```

### Monitor During Model Load:
```bash
watch -n1 'cat /sys/class/drm/card0/device/mem_info_vram_used'
```

---

## Expected Behavior (After Fix)

### When You Select a Model in Big-AGI:

**First request:**
1. LocalAI receives request
2. Checks if model is loaded
3. If not loaded, loads model into VRAM (~10-30 seconds)
4. Generates response

**Subsequent requests:**
- Model already in VRAM
- Instant start
- Fast generation

**Switching models:**
- LocalAI unloads previous model
- Loads new model
- ~10-30 second delay

---

## Summary

### ✅ What's Working:
- LiteLLM proxying all models + Claude
- Models files downloaded correctly
- GPU detected properly
- Configuration correct (HSA_OVERRIDE_GFX_VERSION=10.3.0)

### ❌ What's Broken:
- LocalAI backend (RPC/gRPC failures)
- Models not loading despite being present
- HIP/ROCm backend not functioning

### 🔧 Fix Required:
- Rebuild LocalAI with proper ROCm backend
- OR use different LocalAI image
- OR manually build llama.cpp with HIP support

### 📝 Your Models Are Safe:
- All model files intact in `/models`
- 14GB Qwen, 12GB GPT-OSS, 4.6GB LLaMA, etc.
- No need to re-download

---

## Ready to Rebuild?

Next steps:
1. Backup current LocalAI volumes ✓
2. Stop LocalAI container ✓
3. Try `localai/localai:latest-gpu-hipblas` (no AIO)
4. If that fails, try `localai/localai:latest-rocm`
5. If that fails, build llama.cpp manually

This will be an iterative process, but we'll get GPU acceleration working!
