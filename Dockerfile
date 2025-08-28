# pick ONE of these:
# FROM valyriantech/comfyui-with-flux:latest
# FROM valyriantech/comfyui-with-flux:11102024
FROM valyriantech/comfyui-with-flux:latest

# 1) Build deps so imgui-bundle can compile once at build time
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential cmake ninja-build pkg-config \
    libx11-dev xorg-dev libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev \
    mesa-common-dev libgl1-mesa-dev libglu1-mesa-dev \
    && rm -rf /var/lib/apt/lists/*

# 2) A small venv baked into the image; use it to run ComfyUI
RUN python3 -m venv /opt/comfy-env \
 && /opt/comfy-env/bin/pip install --upgrade pip

# 3) Depthflow + friends (builds imgui-bundle wheel during image build)
RUN /opt/comfy-env/bin/pip install \
      imgui-bundle==1.6.3 shaderflow==0.9.1 depthflow==0.9.1 opencv-python-headless

# 4) Optional: clone the ComfyUI-Depthflow-Nodes into the image
RUN mkdir -p /workspace/ComfyUI/custom_nodes \
 && git clone --depth=1 https://github.com/akatz-ai/ComfyUI-Depthflow-Nodes.git \
      /workspace/ComfyUI/custom_nodes/ComfyUI-Depthflow-Nodes

# 5) Slim down: keep only the runtime libs (the wheel is already built)
RUN apt-get purge -y --auto-remove build-essential cmake ninja-build pkg-config \
    libx11-dev xorg-dev libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev \
    mesa-common-dev libgl1-mesa-dev libglu1-mesa-dev \
 && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    libgl1 libglib2.0-0 \
 && rm -rf /var/lib/apt/lists/*

# 6) Make sure we use our venv by default
ENV PATH="/opt/comfy-env/bin:${PATH}"

# Their template calls a persistent /workspace/start_user.sh on boot—keep that flow.
# We just default to starting ComfyUI with our venv if nothing overrides it.
CMD ["python", "/workspace/ComfyUI/main.py", "--listen", "0.0.0.0", "--port", "8188"]
