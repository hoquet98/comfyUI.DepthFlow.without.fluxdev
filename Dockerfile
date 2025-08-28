# Base WITHOUT models (you already have models in /workspace)
FROM valyriantech/comfyui-without-flux:latest

ARG VENV_DIR=/opt/comfy-env
ENV PATH="${VENV_DIR}/bin:${PATH}" \
    PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1

# --- Only tiny RUNTIME libs needed at import time (no headers, no compilers) ---
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      libgl1 libglib2.0-0 \
      libx11-6 libxrandr2 libxinerama1 libxcursor1 libxi6 \
  && rm -rf /var/lib/apt/lists/*

# --- Create venv and upgrade basic tooling ---
RUN python3 -m venv "${VENV_DIR}" \
 && "${VENV_DIR}/bin/pip" install --upgrade pip setuptools wheel

# --- Install Depthflow stack using PREBUILT wheels only (no compiling) ---
# If a wheel isn't available, pip will fail fast instead of trying to build from source.
RUN PIP_ONLY_BINARY=":all:" "${VENV_DIR}/bin/pip" install \
      imgui-bundle==1.6.3 \
  && "${VENV_DIR}/bin/pip" install \
      shaderflow==0.9.1 \
      depthflow==0.9.1 \
      opencv-python-headless

# --- Optional: include the ComfyUI Depthflow custom node ---
RUN mkdir -p /workspace/ComfyUI/custom_nodes \
 && git clone --depth=1 https://github.com/akatz-ai/ComfyUI-Depthflow-Nodes.git \
      /workspace/ComfyUI/custom_nodes/ComfyUI-Depthflow-Nodes

# Quick import smoke test (fails the build early if something's wrong)
RUN python - <<'PY'
import imgui_bundle, cv2
from broken.core.extra.loaders import LoadImage
import shaderflow
print("Depthflow deps OK:", getattr(imgui_bundle, "__version__", "imgui ok"))
PY

EXPOSE 8188
CMD ["python", "/workspace/ComfyUI/main.py", "--listen", "0.0.0.0", "--port", "8188"]
