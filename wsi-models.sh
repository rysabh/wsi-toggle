WSI_MODEL_DIR="${WSI_MODEL_DIR:-$HOME/Applications/whisper.cpp/models}"
WSI_MODEL="${WSI_MODEL:-medium.en}" # base.en | medium.en | large-v3 | large-v3-turbo
MODEL_ON_DISK="${MODEL_ON_DISK:-$WSI_MODEL_DIR/ggml-$WSI_MODEL.bin}"
