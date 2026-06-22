import os
import time
import requests
import boto3
from pathlib import Path

# Configuráveis via ENV:
TAXON_IDS = [18938, 18937]
SPECIES_NAMES = os.getenv("SPECIES_NAMES", "")  # comma-separated species names

BASE_API = "https://api.inaturalist.org/v1"
OBSERVATIONS_URL = f"{BASE_API}/observations"
TAXA_URL = f"{BASE_API}/taxa"

S3_RAW_BUCKET = os.getenv("S3_RAW_BUCKET", "ai-pipeline-s3-raw")
BATCH_JOB_QUEUE = os.getenv("BATCH_JOB_QUEUE", "")
BATCH_JOB_DEF = os.getenv("BATCH_JOB_DEF", "")
OUTPUT_DIR = Path("/tmp/dataset")

PER_PAGE = int(os.getenv("PER_PAGE", "200"))

USER_AGENT = os.getenv("USER_AGENT", "TCC-download/1.0 (projeto academico; contato: aluno@sptech.school)")
HEADERS = {"User-Agent": USER_AGENT}

s3_client = boto3.client("s3")
batch_client = boto3.client("batch")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


def upload_to_s3(local_path, bucket, key):
    try:
        s3_client.upload_file(str(local_path), bucket, key)
        print(f"Upload: {local_path} -> s3://{bucket}/{key}")
    except Exception as e:
        print(f"Erro ao enviar {local_path} para S3: {e}")
        raise


def submit_batch_job():
    """Dispara um job no AWS Batch para data augmentation"""
    if not BATCH_JOB_QUEUE or not BATCH_JOB_DEF:
        print("BATCH_JOB_QUEUE ou BATCH_JOB_DEF não configurados. Pulando...")
        return
    
    try:
        response = batch_client.submit_job(
            jobName=f"data-augmentation-{int(os.times()[4])}",
            jobQueue=BATCH_JOB_QUEUE,
            jobDefinition=BATCH_JOB_DEF
        )
        print(f"✅ Batch job enviado! Job ID: {response['jobId']}")
        return response['jobId']
    except Exception as e:
        print(f"❌ Erro ao enviar Batch job: {e}")
        raise


def resolve_taxon(name: str):
    """Resolve um nome científico para taxon_id usando /taxa."""
    try:
        resp = requests.get(TAXA_URL, params={"q": name, "rank": "species"}, headers=HEADERS, timeout=30)
        resp.raise_for_status()
        results = resp.json().get("results", [])
        if not results:
            print(f"Não encontrei taxon para '{name}'")
            return None
        taxon = results[0]
        tid = taxon.get("id")
        print(f"Resolveu '{name}' -> taxon_id={tid}")
        return tid
    except Exception as e:
        print(f"Erro ao resolver taxon '{name}': {e}")
        return None


def download_image(url, filepath):
    try:
        response = requests.get(url, timeout=30)

        if response.status_code == 200:
            filepath.parent.mkdir(parents=True, exist_ok=True)
            with open(filepath, "wb") as f:
                f.write(response.content)

            print(f"Download: {filepath}")
            return True

    except Exception as e:
        print(f"Erro ao baixar {url}: {e}")

    return False


def iterate_taxon(taxon_id: int):
    species_dir = Path(OUTPUT_DIR) / str(taxon_id)
    species_dir.mkdir(parents=True, exist_ok=True)

    page = 1
    total_downloaded = 0

    print(f"\nColetando taxon_id={taxon_id}")

    while True:
        params = {
            "taxon_id": taxon_id,
            "photos": "true",
            "per_page": PER_PAGE,
            "page": page,
            "quality_grade": "research",
            "order_by": "votes",
        }

        resp = requests.get(OBSERVATIONS_URL, params=params, headers=HEADERS, timeout=30)
        try:
            resp.raise_for_status()
        except Exception as e:
            print(f"Erro na requisição de observações: {e}")
            break

        data = resp.json()
        results = data.get("results", [])

        if not results:
            break

        for observation in results:
            photos = observation.get("photos", [])
            for photo in photos:
                photo_url = photo.get("url")
                if not photo_url:
                    continue
                # troca tamanho small por original
                photo_url = photo_url.replace("square", "original")
                extension = photo_url.split(".")[-1].split("?")[0]
                filename = f"{observation['id']}_{photo['id']}.{extension}"
                filepath = species_dir / filename
                if filepath.exists():
                    continue
                if download_image(photo_url, filepath):
                    s3_key = f"images/{filename}"
                    upload_to_s3(filepath, S3_RAW_BUCKET, s3_key)
                    total_downloaded += 1

        print(f"Taxon {taxon_id} | Página {page} | Imagens: {total_downloaded}")
        page += 1

    print(f"Finalizado taxon {taxon_id} ({total_downloaded} imagens)")


def main():
    # Resolve species names se fornecidas
    taxon_list = []
    if SPECIES_NAMES:
        for name in [s.strip() for s in SPECIES_NAMES.split(",") if s.strip()]:
            tid = resolve_taxon(name)
            if tid:
                taxon_list.append(tid)

    if not taxon_list:
        taxon_list = TAXON_IDS

    for tid in taxon_list:
        iterate_taxon(tid)

    print("\n✅ Download concluído!")
    print("📦 Disparando AWS Batch para data augmentation...")
    submit_batch_job()


if __name__ == "__main__":
    main()