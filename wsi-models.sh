WSI_MODEL_DIR="${WSI_MODEL_DIR:-$HOME/Applications/whisper.cpp/models}"
WSI_MODELS="${WSI_MODELS:-base.en medium.en large-v3 large-v3-turbo}"
# Default model. large-v3 beats large-v3-turbo on jargon (fiducial, peg-and-hole,
# pack truss, strawman, etc.) at ~2x the runtime. Use turbo for speed:
#   WSI_MODEL=large-v3-turbo wsi-file ...
WSI_MODEL="${WSI_MODEL:-large-v3}" # base.en | medium.en | large-v3 | large-v3-turbo

MODEL_ON_DISK="${MODEL_ON_DISK:-$WSI_MODEL_DIR/ggml-$WSI_MODEL.bin}"

# --- Anti-loop decoding defaults (consumed by wsi-file Step 3) ---
# Whisper falls into runaway repetition loops on long files. Two causes, two knobs:
#   WSI_VAD=1         -> strip non-speech audio (silence/applause/pauses) before it
#                        reaches Whisper. Non-speech is what *ignites* the loop.
#   WSI_MAX_CONTEXT=0 -> don't carry generated text across 30s windows, so a loop
#                        can't *propagate*. (-1 restores Whisper's unbounded default.)
# A/B test the old bare behavior with:  WSI_VAD=0 WSI_MAX_CONTEXT=-1 wsi-file ...
WSI_VAD="${WSI_VAD:-1}"
WSI_VAD_MODEL="${WSI_VAD_MODEL:-$WSI_MODEL_DIR/ggml-silero-v5.1.2.bin}"
WSI_MAX_CONTEXT="${WSI_MAX_CONTEXT:-0}"
