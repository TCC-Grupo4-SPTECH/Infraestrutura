#!/bin/bash

set -e

echo "======================================"
echo "🚀 INICIANDO SETUP EC2 YOLO + S3"
echo "======================================"

# 1. Atualizar sistema
echo "🔄 Atualizando sistema..."
if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update && sudo apt-get upgrade -y
    PKG_INSTALL="sudo apt-get install -y"
    EXTRA_PKGS="cloud-guest-utils python3-venv"
    BASE_PKGS="python3 python3-pip $EXTRA_PKGS awscli unzip curl xfsprogs libxcb1 libx11-6 libgl1 libglib2.0-0"
elif command -v dnf >/dev/null 2>&1; then
    sudo dnf upgrade -y
    PKG_INSTALL="sudo dnf install -y"
    EXTRA_PKGS="cloud-utils-growpart python3-virtualenv"
    BASE_PKGS="python3 python3-pip $EXTRA_PKGS awscli unzip xfsprogs libxcb libX11 libXext libXrender mesa-libGL mesa-libEGL"
elif command -v yum >/dev/null 2>&1; then
    sudo yum update -y
    PKG_INSTALL="sudo yum install -y"
    EXTRA_PKGS="cloud-utils-growpart python3-virtualenv"
    BASE_PKGS="python3 python3-pip $EXTRA_PKGS awscli unzip xfsprogs libxcb libX11 libXext libXrender mesa-libGL mesa-libEGL"
else
    echo "❌ Gerenciador de pacotes não suportado"
    exit 1
fi

# 2. Instalar dependências básicas
echo "📦 Instalando dependências..."
$PKG_INSTALL $BASE_PKGS

# 3. Detectar disco principal
echo "💽 Detectando disco principal..."
ROOT_DEVICE=$(findmnt -n -o SOURCE /)
ROOT_DISK=$(lsblk -no PKNAME "$ROOT_DEVICE" | head -n 1)
ROOT_PARTITION="${ROOT_DEVICE##*[!0-9]}"

if [[ -n "$ROOT_DISK" && -n "$ROOT_PARTITION" ]]; then
    echo "✔ Disco detectado: /dev/$ROOT_DISK, partição $ROOT_PARTITION"

    # A expansão é opcional e não deve impedir o restante do setup.
    echo "📈 Expandindo partição (se aplicável)..."
    sudo growpart "/dev/$ROOT_DISK" "$ROOT_PARTITION" || true
else
    echo "⚠ Não foi possível detectar a partição raiz; pulando expansão do disco"
fi

echo "✔ Etapa de expansão concluída (se aplicável)"

# 5. Aumentar /tmp (evita erro do PyTorch)
echo "🧠 Ajustando /tmp..."
sudo mount -o remount,size=2G /tmp || true

YOLO_ENV_DIR="/opt/yolo-env"
YOLO_TMP_DIR="/opt/yolo-tmp"

ROOT_FILESYSTEM=$(findmnt -n -o FSTYPE /)
if [[ "$ROOT_FILESYSTEM" == "xfs" ]]; then
    sudo xfs_growfs / || true
elif [[ "$ROOT_FILESYSTEM" == "ext4" ]]; then
    sudo resize2fs "$ROOT_DEVICE" || true
fi

# 6. Criar diretório temporário alternativo
mkdir -p "$YOLO_TMP_DIR"
export TMPDIR="$YOLO_TMP_DIR"

# 7. Criar ambiente virtual
echo "🐍 Criando ambiente Python..."
python3 -m venv "$YOLO_ENV_DIR"

source "$YOLO_ENV_DIR/bin/activate"

# 8. Atualizar pip
echo "⬆️ Atualizando pip..."
pip install --upgrade pip

# 9. Instalar YOLO e boto3
echo "🤖 Instalando YOLO + boto3 + albumentations..."
pip install --no-cache-dir ultralytics boto3 albumentations

# 10. Configurar AWS CLI
if [[ -n "$AWS_ACCESS_KEY_ID" && -n "$AWS_SECRET_ACCESS_KEY" ]]; then
    echo "🔐 Configuração AWS CLI via variáveis de ambiente"
    aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
    aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
    if [[ -n "$AWS_SESSION_TOKEN" ]]; then
        aws configure set aws_session_token "$AWS_SESSION_TOKEN"
    fi
    if [[ -n "$AWS_REGION" ]]; then
        aws configure set region "$AWS_REGION"
    fi
    aws configure set output json
    echo "✔ AWS configurado via variáveis de ambiente"
else
    echo "🔐 Usando credenciais da instância AWS IAM Role ou metadados"
fi

# 11. Teste AWS
echo "🧪 Testando AWS..."
aws sts get-caller-identity || echo "⚠ AWS não validado (verifique o perfil de instância ou as credenciais)"

# 12. Finalização
echo "======================================"
echo "✅ SETUP CONCLUÍDO COM SUCESSO"
echo "======================================"

echo "Para ativar o ambiente depois:"
echo "source $YOLO_ENV_DIR/bin/activate"
echo ""
echo "Para rodar seu script:"
echo "python yolo_test.py"