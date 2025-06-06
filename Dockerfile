# ---------------------------------------------------------------------------- #
#                         Stage 1: Download the models                         #
# ---------------------------------------------------------------------------- #
FROM alpine/git:2.43.0 as download

# 創建必要的目錄
RUN mkdir -p /models/LoRA

# 下載主模型
RUN apk add --no-cache wget && \
    wget -q -O /model.safetensors https://huggingface.co/CuteBlueEyed/GeminiX/resolve/main/Gemini_ILMixV5.safetensors

# 下載 LoRA 模型
RUN wget -q -O /models/LoRA/Fenny_GMIL_TAV1.safetensors https://huggingface.co/CuteBlueEyed/LoRAForGeminiX_IL/resolve/main/Fenny_GMIL_TAV1.safetensors && \
    wget -q -O /models/LoRA/Anna_GMIL_TAV1.safetensors https://huggingface.co/CuteBlueEyed/LoRAForGeminiX_IL/resolve/main/Anna_GMIL_TAV1.safetensors && \
    wget -q -O /models/LoRA/KURA_GMIL_TAV1.safetensors https://huggingface.co/CuteBlueEyed/LoRAForGeminiX_IL/resolve/main/KURA_GMIL_TAV1.safetensors

# ---------------------------------------------------------------------------- #
#                        Stage 2: Build the final image                        #
# ---------------------------------------------------------------------------- #
FROM python:3.10.14-slim as build_final_image

ARG A1111_RELEASE=v1.9.3

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    ROOT=/stable-diffusion-webui \
    PYTHONUNBUFFERED=1

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && \
    apt install -y \
    fonts-dejavu-core rsync git jq moreutils aria2 wget libgoogle-perftools-dev libtcmalloc-minimal4 procps libgl1 libglib2.0-0 && \
    apt-get autoremove -y && rm -rf /var/lib/apt/lists/* && apt-get clean -y

RUN --mount=type=cache,target=/root/.cache/pip \
    git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git && \
    cd stable-diffusion-webui && \
    git reset --hard ${A1111_RELEASE} && \
    pip install xformers && \
    pip install -r requirements_versions.txt && \
    python -c "from launch import prepare_environment; prepare_environment()" --skip-torch-cuda-test

# 複製模型檔案
COPY --from=download /model.safetensors /stable-diffusion-webui/models/Stable-diffusion/
COPY --from=download /models/LoRA /stable-diffusion-webui/models/Lora/

# install dependencies
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir -r requirements.txt

COPY test_input.json .

ADD src .

RUN chmod +x /start.sh
CMD /start.sh
