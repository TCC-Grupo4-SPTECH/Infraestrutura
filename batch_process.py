import os
import cv2
import boto3
import tempfile
import logging
from pathlib import Path
import albumentations as A

# Configuração de logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

S3_RAW_BUCKET = os.getenv("S3_RAW_BUCKET", "ai-pipeline-s3-raw")
S3_TRUSTED_BUCKET = os.getenv("S3_TRUSTED_BUCKET", "ai-pipeline-s3-trusted")
AUGMENTATIONS_PER_IMAGE = int(os.getenv("AUGMENTATIONS_PER_IMAGE", 10))

TEMP_DIR = tempfile.mkdtemp()
INPUT_DIR = os.path.join(TEMP_DIR, "input")
OUTPUT_DIR = os.path.join(TEMP_DIR, "output")

os.makedirs(INPUT_DIR, exist_ok=True)
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Cliente S3
s3_client = boto3.client("s3")

# Transformações Albumentations
transform = A.Compose([
    A.HorizontalFlip(p=0.5),
    A.RandomBrightnessContrast(
        brightness_limit=0.2,
        contrast_limit=0.2,
        p=0.5
    ),
    A.HueSaturationValue(
        hue_shift_limit=10,
        sat_shift_limit=20,
        val_shift_limit=10,
        p=0.5
    ),
    A.Superpixels(
        p_replace=0.3,
        n_segments=50,
        p=0.3
    ),
    A.Rotate(
        limit=15,
        border_mode=cv2.BORDER_CONSTANT,
        p=0.5
    ),
    A.MotionBlur(
        blur_limit=(3, 5),
        p=0.3
    ),
    A.RandomFog(
        fog_coef_range=(0.05, 0.1),
        alpha_coef=0.08,
        p=0.3
    ),
    A.RandomScale(
        scale_limit=0.2,
        p=0.5
    ),
    A.Perspective(
        scale=(0.02, 0.05),
        p=0.3
    ),
    A.ImageCompression(
        quality_range=(70, 100),
        p=0.3
    ),
], bbox_params=A.BboxParams(
    format='yolo',
    label_fields=['class_labels'],
    min_visibility=0.3
))


def download_from_s3(bucket, prefix, local_path):
    """Baixa arquivos do S3 para pasta local."""
    try:
        response = s3_client.list_objects_v2(Bucket=bucket, Prefix=prefix)
        
        if "Contents" not in response:
            logger.warning(f"Nenhum arquivo encontrado em s3://{bucket}/{prefix}")
            return []
        
        downloaded_files = []
        for obj in response["Contents"]:
            key = obj["Key"]
            if key.endswith("/"):
                continue
                
            local_file = os.path.join(local_path, os.path.basename(key))
            s3_client.download_file(bucket, key, local_file)
            downloaded_files.append(local_file)
            logger.info(f"Baixado: s3://{bucket}/{key} → {local_file}")
        
        return downloaded_files
    
    except Exception as e:
        logger.error(f"Erro ao baixar de S3: {e}")
        raise


def upload_to_s3(bucket, local_file, s3_key):
    """Faz upload de arquivo para S3."""
    try:
        s3_client.upload_file(local_file, bucket, s3_key)
        logger.info(f"Enviado: {local_file} → s3://{bucket}/{s3_key}")
    except Exception as e:
        logger.error(f"Erro ao fazer upload para S3: {e}")
        raise


def load_yolo_labels(label_path):
    """Carrega labels no formato YOLO."""
    bboxes = []
    class_labels = []

    try:
        with open(label_path, "r") as f:
            lines = f.readlines()

        for line in lines:
            if not line.strip():
                continue
            
            parts = line.strip().split()
            class_id = int(parts[0])
            x, y, w, h = map(float, parts[1:])

            bboxes.append([x, y, w, h])
            class_labels.append(class_id)
    
    except Exception as e:
        logger.error(f"Erro ao carregar labels {label_path}: {e}")
        return [], []

    return bboxes, class_labels


def save_yolo_labels(path, bboxes, class_labels):
    """Salva labels no formato YOLO."""
    try:
        with open(path, "w") as f:
            for bbox, class_id in zip(bboxes, class_labels):
                x, y, w, h = bbox
                line = f"{class_id} {x} {y} {w} {h}\n"
                f.write(line)
        logger.info(f"Labels salvos: {path}")
    except Exception as e:
        logger.error(f"Erro ao salvar labels {path}: {e}")
        raise


def process_and_augment_images():
    """Processa e aumenta imagens."""
    
    logger.info("Iniciando download do S3...")
    image_files = download_from_s3(S3_RAW_BUCKET, "images/", INPUT_DIR)
    
    if not image_files:
        logger.error("Nenhuma imagem encontrada para processar!")
        return
    
    logger.info(f"Processando {len(image_files)} imagens...")
    
    augmented_count = 0
    
    for image_file in image_files:
        filename = os.path.basename(image_file)
        label_file = os.path.join(INPUT_DIR, os.path.splitext(filename)[0] + ".txt")
        
        # if not os.path.exists(label_file):
        #     logger.warning(f"Label não encontrada para {filename}")
        #     continue
        
        # Carrega imagem
        image = cv2.imread(image_file)
        if image is None:
            logger.error(f"Erro ao carregar imagem: {filename}")
            continue
        
        bboxes, class_labels = load_yolo_labels(label_file)
        
        # Salva imagem original no output
        output_image_original = os.path.join(OUTPUT_DIR, filename)
        cv2.imwrite(output_image_original, image)
        
        output_label_original = os.path.join(OUTPUT_DIR, os.path.splitext(filename)[0] + ".txt")
        save_yolo_labels(output_label_original, bboxes, class_labels)
        
        # Gera aumentações
        for i in range(AUGMENTATIONS_PER_IMAGE):
            try:
                transformed = transform(
                    image=image,
                    bboxes=bboxes,
                    class_labels=class_labels
                )
                
                aug_image = transformed["image"]
                aug_bboxes = transformed["bboxes"]
                aug_labels = transformed["class_labels"]
                
                base_name = os.path.splitext(filename)[0]
                new_name = f"{base_name}_aug_{i}"
                
                output_image_path = os.path.join(OUTPUT_DIR, new_name + ".jpg")
                output_label_path = os.path.join(OUTPUT_DIR, new_name + ".txt")
                
                cv2.imwrite(output_image_path, aug_image)
                save_yolo_labels(output_label_path, aug_bboxes, aug_labels)
                
                augmented_count += 1
                logger.info(f"Augmentação criada: {new_name}")
            
            except Exception as e:
                logger.error(f"Erro ao aumentar {filename} (iteração {i}): {e}")
                continue
    
    logger.info(f"Total de {augmented_count} aumentações criadas")
    return augmented_count


def upload_results_to_s3():
    """Faz upload dos resultados para S3 trusted."""
    logger.info("Fazendo upload dos resultados para S3...")
    
    upload_count = 0
    for local_file in Path(OUTPUT_DIR).rglob("*"):
        if local_file.is_file():
            relative_path = local_file.relative_to(OUTPUT_DIR)
            s3_key = f"processed/{relative_path}".replace("\\", "/")
            
            upload_to_s3(S3_TRUSTED_BUCKET, str(local_file), s3_key)
            upload_count += 1
    
    logger.info(f"Upload concluído: {upload_count} arquivos enviados")
    return upload_count


def cleanup_temp_files():
    """Remove arquivos temporários."""
    try:
        import shutil
        shutil.rmtree(TEMP_DIR)
        logger.info(f"Arquivos temporários removidos: {TEMP_DIR}")
    except Exception as e:
        logger.error(f"Erro ao limpar arquivos temporários: {e}")


def main():
    """Função principal."""
    try:
        logger.info("=" * 60)
        logger.info("INICIANDO PROCESSAMENTO AWS BATCH - YOLO Augmentation")
        logger.info("=" * 60)
        logger.info(f"S3 Raw Bucket: {S3_RAW_BUCKET}")
        logger.info(f"S3 Trusted Bucket: {S3_TRUSTED_BUCKET}")
        logger.info(f"Augmentações por imagem: {AUGMENTATIONS_PER_IMAGE}")
        logger.info("=" * 60)
        
        # Processa e aumenta
        augmented = process_and_augment_images()
        
        # Faz upload dos resultados
        uploaded = upload_results_to_s3()
        
        logger.info("=" * 60)
        logger.info("PROCESSAMENTO CONCLUÍDO COM SUCESSO")
        logger.info(f"Aumentações criadas: {augmented}")
        logger.info(f"Arquivos enviados: {uploaded}")
        logger.info("=" * 60)
    
    except Exception as e:
        logger.error(f"Erro fatal no processamento: {e}", exc_info=True)
        raise
    
    finally:
        cleanup_temp_files()


if __name__ == "__main__":
    main()
