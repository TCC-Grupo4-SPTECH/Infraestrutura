import os
import requests
import boto3
from pathlib import Path

TAXON_IDS = [18938, 18937]

BASE_URL = "https://api.inaturalist.org/v1/observations"
S3_RAW_BUCKET = os.getenv("S3_RAW_BUCKET", "ai-pipeline-s3-raw")
OUTPUT_DIR = Path("/tmp/dataset")

PER_PAGE = 200

s3_client = boto3.client("s3")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


def upload_to_s3(local_path, bucket, key):
    try:
        s3_client.upload_file(str(local_path), bucket, key)
        print(f"Upload: {local_path} -> s3://{bucket}/{key}")
    except Exception as e:
        print(f"Erro ao enviar {local_path} para S3: {e}")
        raise


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


for taxon_id in TAXON_IDS:

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
            "page": page
        }

        response = requests.get(BASE_URL, params=params)

        data = response.json()

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

                filename = (
                    f"{observation['id']}_{photo['id']}.{extension}"
                )

                filepath = species_dir / filename

                if filepath.exists():
                    continue

                if download_image(photo_url, filepath):
                    s3_key = f"images/{filename}"
                    upload_to_s3(filepath, S3_RAW_BUCKET, s3_key)
                    total_downloaded += 1

        print(
            f"Taxon {taxon_id} | Página {page} | "
            f"Imagens: {total_downloaded}"
        )

        page += 1

    print(
        f"Finalizado taxon {taxon_id} "
        f"({total_downloaded} imagens)"
    )

print("\nDownload concluído.")