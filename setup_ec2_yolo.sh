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
elif command -v dnf >/dev/null 2>&1; then
    sudo dnf upgrade -y
    PKG_INSTALL="sudo dnf install -y"
    EXTRA_PKGS="cloud-utils-growpart python3-virtualenv"
elif command -v yum >/dev/null 2>&1; then
    sudo yum update -y
    PKG_INSTALL="sudo yum install -y"
    EXTRA_PKGS="cloud-utils-growpart python3-virtualenv"
else
    echo "❌ Gerenciador de pacotes não suportado"
    exit 1
fi

# 2. Instalar dependências básicas
echo "📦 Instalando dependências..."
$PKG_INSTALL python3 python3-pip $EXTRA_PKGS awscli unzip curl

# 3. Detectar disco principal
echo "💽 Detectando disco principal..."
ROOT_DISK=$(lsblk -o MOUNTPOINT,NAME | grep " /$" | awk '{print $2}' | sed 's/└─//g' | sed 's/├─//g' | head -n 1)

if [[ "$ROOT_DISK" == "" ]]; then
    echo "❌ Não foi possível detectar o disco automaticamente"
    exit 1
fi

echo "✔ Disco detectado: $ROOT_DISK"

# 4. Expandir partição (EC2)
echo "📈 Expandindo disco..."
sudo growpart /dev/nvme0n1 1 || true
sudo resize2fs /dev/nvme0n1p1 || true

echo "✔ Disco expandido (se aplicável)"

# 5. Aumentar /tmp (evita erro do PyTorch)
echo "🧠 Ajustando /tmp..."
sudo mount -o remount,size=2G /tmp || true

# 6. Criar diretório temporário alternativo
mkdir -p ~/tmp
export TMPDIR=~/tmp

# 7. Criar ambiente virtual
echo "🐍 Criando ambiente Python..."
python3 -m venv yolo-env

source yolo-env/bin/activate

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
echo "source yolo-env/bin/activate"
echo ""
echo "Para rodar seu script:"
echo "python yolo_test.py"