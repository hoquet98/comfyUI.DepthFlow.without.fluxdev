# Base: WITHOUT models since your volume already has them
# Consider pinning a tag from Valyrian's repo instead of latest
FROM valyriantech/comfyui-without-flux:latest

ARG VENV_DIR=/opt/comfy-env
ENV PATH="${VENV_DIR}/bin:${PATH}" \
    PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1

# --- Build-time deps so imgui-bundle/GLFW can compile once ---
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential cmake ninja-build pkg-config \
    libx11-dev xorg-dev libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev \
    mesa-common-dev libgl1-mesa-dev libglu1-mesa-dev \
 && rm -rf /var/lib/apt/lists/*

# --- venv for ComfyUI runtime & Depthflow deps ---
RUN python3 -m venv "${VENV_DIR}" \
 && "${VENV_DIR}/bin/pip" install --upgrade pip setuptools wheel

# --- Install Depthflow + deps (build imgui-bundle now) ---
RUN "${VENV_DIR}/bin/pip" install \
      imgui-bundle==1.6.3 \
      shaderflow==0.9.1 \
      depthflow==0.9.1 \
      opencv-python-headless

# --- Optional: include the ComfyUI-Depthflow custom node ---
RUN mkdir -p /workspace/ComfyUI/custom_nodes \
 && git clone --depth=1 https://github.com/akatz-ai/ComfyUI-Depthflow-Nodes.git \
      /workspace/ComfyUI/custom_nodes/ComfyUI-Depthflow-Nodes

# --- Verify imports at build time (early failure if something’s off) ---
RUN python - <<'PY'
import imgui_bundle, cv2
from broken.core.extra.loaders import LoadImage
import shaderflow
print("Depthflow stack OK:", getattr(imgui_bundle, "__version__", "imgui ok"))
PY

# --- Remove build deps; keep minimal runtime libs (GL + X11 runtimes) ---
RUN apt-get purge -y --auto-remove \
      build-essential cmake ninja-build pkg-config \
      libx11-dev xorg-dev libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev \
      mesa-common-dev libgl1-mesa-dev libglu1-mesa-dev \
 && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      libgl1 libglib2.0-0 \
      libx11-6 libxrandr2 libxinerama1 libxcursor1 libxi6 \
 && rm -rf /var/lib/apt/lists/*

EXPOSE 8188

# Start ComfyUI; Valyrian's flow also calls /workspace/start_user.sh if present
CMD ["python", "/workspace/ComfyUI/main.py", "--listen", "0.0.0.0", "--port", "8188"]
