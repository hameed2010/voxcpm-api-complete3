#!/usr/bin/env bash
set -e

# ============================================================
# VoxCPM API - RunPod Setup & Startup
# ============================================================

PROJECT="/workspace/voxcpm-api-complete3"
REPO="https://github.com/hameed2010/voxcpm-api-complete3.git"

PYTHON_BIN="$PROJECT/.venv/bin/python"

echo ""
echo "============================================================"
echo "🚀 VoxCPM API - RunPod Setup"
echo "============================================================"
echo ""

# ============================================================
# 1. Clone Project
# ============================================================

if [ ! -d "$PROJECT/.git" ]; then

    echo "📥 Cloning repository..."

    cd /workspace
    git clone "$REPO"

else

    echo "📦 Project already exists"
    cd "$PROJECT"

    git pull --ff-only || true

fi

cd "$PROJECT"

# ============================================================
# 2. Create Virtual Environment
# ============================================================

if [ ! -d "$PROJECT/.venv" ]; then

    echo "🐍 Creating Python virtual environment..."

    python3 -m venv .venv

else

    echo "✓ Virtual environment already exists"

fi

# ============================================================
# 3. Activate Virtual Environment
# ============================================================

source "$PROJECT/.venv/bin/activate"

echo ""
echo "Python:"
python --version

# ============================================================
# 4. Upgrade pip
# ============================================================

echo ""
echo "⬆️ Upgrading pip..."

python -m pip install --upgrade pip setuptools wheel

# ============================================================
# 5. Install PyTorch CUDA 12.8
# ============================================================

echo ""
echo "🔥 Installing PyTorch CUDA 12.8..."

python -m pip install \
    torch==2.8.0 \
    torchvision==0.23.0 \
    torchaudio==2.8.0 \
    --index-url https://download.pytorch.org/whl/cu128

# ============================================================
# 6. Remove torch from requirements.txt
# ============================================================

if [ -f "$PROJECT/requirements.txt" ]; then

    echo ""
    echo "🧹 Removing torch from requirements.txt..."

    sed -i '/^[[:space:]]*torch[[:space:]]*$/d' \
        "$PROJECT/requirements.txt"

fi

# ============================================================
# 7. Install Requirements
# ============================================================

if [ -f "$PROJECT/requirements.txt" ]; then

    echo ""
    echo "📦 Installing project requirements..."

    python -m pip install -r "$PROJECT/requirements.txt"

fi

# ============================================================
# 8. HuggingFace / Whisper Cache
# ============================================================

echo ""
echo "📁 Creating cache directories..."

mkdir -p \
    /workspace/.cache/huggingface \
    /workspace/.cache/huggingface/hub \
    /workspace/.cache/whisper

# ============================================================
# 9. Environment Variables
# ============================================================

export HF_HOME="/workspace/.cache/huggingface"
export HUGGINGFACE_HUB_CACHE="/workspace/.cache/huggingface/hub"
export XDG_CACHE_HOME="/workspace/.cache"

# ============================================================
# 10. Save Environment Variables
# ============================================================

echo ""
echo "⚙️ Configuring environment variables..."

touch /workspace/.bashrc

grep -qxF \
    'export HF_HOME="/workspace/.cache/huggingface"' \
    /workspace/.bashrc \
    || echo 'export HF_HOME="/workspace/.cache/huggingface"' \
    >> /workspace/.bashrc

grep -qxF \
    'export HUGGINGFACE_HUB_CACHE="/workspace/.cache/huggingface/hub"' \
    /workspace/.bashrc \
    || echo 'export HUGGINGFACE_HUB_CACHE="/workspace/.cache/huggingface/hub"' \
    >> /workspace/.bashrc

grep -qxF \
    'export XDG_CACHE_HOME="/workspace/.cache"' \
    /workspace/.bashrc \
    || echo 'export XDG_CACHE_HOME="/workspace/.cache"' \
    >> /workspace/.bashrc

# ============================================================
# 11. Create .env
# ============================================================

echo ""
echo "🔐 Configuring .env..."

if [ ! -f "$PROJECT/.env" ]; then

    if [ -f "$PROJECT/.env.example" ]; then

        cp "$PROJECT/.env.example" "$PROJECT/.env"

        echo "✓ .env created"

    else

        echo "⚠ .env.example not found"

    fi

else

    echo "✓ .env already exists"

fi

# ============================================================
# 12. Create startup.sh
# ============================================================

echo ""
echo "📝 Creating startup.sh..."

cat > "$PROJECT/startup.sh" <<'STARTUP_EOF'
#!/usr/bin/env bash
set -e

PROJECT="/workspace/voxcpm-api-complete3"
PYTHON="$PROJECT/.venv/bin/python"

export HF_HOME="/workspace/.cache/huggingface"
export HUGGINGFACE_HUB_CACHE="/workspace/.cache/huggingface/hub"
export XDG_CACHE_HOME="/workspace/.cache"

cd "$PROJECT"

echo ""
echo "============================================================"
echo "🚀 VoxCPM API"
echo "============================================================"

echo "📂 Project: $PROJECT"
echo "🐍 Python:  $PYTHON"
echo "🎮 GPU:     ${RUNPOD_GPU_NAME:-Unknown}"
echo "📡 Host:    ${HOST:-0.0.0.0}"
echo "🔌 Port:    ${PORT:-8000}"

echo ""

# ============================================================
# GPU CHECK
# ============================================================

echo "============================================================"
echo "🎮 GPU CHECK"
echo "============================================================"

"$PYTHON" - <<'PY'
import torch

print("PyTorch:", torch.__version__)
print("CUDA available:", torch.cuda.is_available())

if torch.cuda.is_available():

    print("CUDA:", torch.version.cuda)
    print("GPU:", torch.cuda.get_device_name(0))
    print("GPU count:", torch.cuda.device_count())

else:

    print("⚠ WARNING: CUDA is not available")

PY

echo ""

# ============================================================
# RunPod Public URL
# ============================================================

if [ -n "${RUNPOD_POD_ID:-}" ]; then

    PUBLIC_URL="https://${RUNPOD_POD_ID}-${PORT:-8000}.proxy.runpod.net"

    echo "============================================================"
    echo "🌍 RUNPOD"
    echo "============================================================"

    echo "Public URL:"
    echo "$PUBLIC_URL"

    echo ""
    echo "Swagger:"
    echo "$PUBLIC_URL/docs"

    echo ""
    echo "OpenAPI:"
    echo "$PUBLIC_URL/openapi.json"

fi

echo ""
echo "============================================================"
echo "🚀 STARTING API"
echo "============================================================"
echo ""

exec "$PYTHON" -m uvicorn app.main:app \
    --host "${HOST:-0.0.0.0}" \
    --port "${PORT:-8000}" \
    --workers 1

STARTUP_EOF

chmod +x "$PROJECT/startup.sh"

# ============================================================
# 13. Installation Check
# ============================================================

echo ""
echo "============================================================"
echo "🔍 INSTALLATION CHECK"
echo "============================================================"

"$PYTHON_BIN" - <<'PY'
import sys

print("Python:", sys.version)

try:

    import torch

    print("PyTorch:", torch.__version__)
    print("CUDA available:", torch.cuda.is_available())

    if torch.cuda.is_available():

        print("CUDA version:", torch.version.cuda)
        print("GPU:", torch.cuda.get_device_name(0))

except Exception as e:

    print("PyTorch error:", e)


try:

    import fastapi

    print("FastAPI:", fastapi.__version__)

except Exception:

    print("FastAPI: NOT FOUND")


try:

    import uvicorn

    print("Uvicorn:", uvicorn.__version__)

except Exception:

    print("Uvicorn: NOT FOUND")

PY

# ============================================================
# 14. Cache Configuration
# ============================================================

echo ""
echo "============================================================"
echo "⚙️ CACHE CONFIGURATION"
echo "============================================================"

echo "HF_HOME=$HF_HOME"
echo "HUGGINGFACE_HUB_CACHE=$HUGGINGFACE_HUB_CACHE"
echo "XDG_CACHE_HOME=$XDG_CACHE_HOME"

# ============================================================
# 15. Start API
# ============================================================

echo ""
echo "============================================================"
echo "🚀 STARTING VOXCPM API"
echo "============================================================"
echo ""

exec "$PROJECT/startup.sh"
