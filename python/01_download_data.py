"""
01_download_data.py

Download the raw spatial data for the ontario-claims-caribou project.

What it does:
- Reads the list of data sources from python/data_sources.yml
- Scrapes the OGSEarth page to find the current mining claims ZIP links
  (falls back to a known URL if the page layout changes)
- Downloads each ZIP to data/raw/ and unzips it into its own folder
- Appends a row per file to data/raw/download_log.csv (what, where, when)

Run from the project root:
    conda activate claims-caribou
    python python/01_download_data.py
"""

import csv
import hashlib
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urljoin

import requests
import yaml
from bs4 import BeautifulSoup

# Paths are built from this file's location, so the script works
# no matter which folder you run it from.
PROJECT_ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = PROJECT_ROOT / "python" / "data_sources.yml"
RAW_DIR = PROJECT_ROOT / "data" / "raw"
LOG_PATH = RAW_DIR / "download_log.csv"

# Identify ourselves politely to the servers we download from.
HEADERS = {
    "User-Agent": "ontario-claims-caribou portfolio project (github.com/emmabranch)"
}
TIMEOUT = 120  # seconds


def find_link(page_url: str, pattern: str) -> str | None:
    """Return the first link on page_url whose address contains pattern."""
    try:
        response = requests.get(page_url, headers=HEADERS, timeout=TIMEOUT)
        response.raise_for_status()
    except requests.RequestException as err:
        print(f"  Could not read {page_url}: {err}")
        return None

    soup = BeautifulSoup(response.text, "html.parser")
    for link in soup.find_all("a", href=True):
        if pattern.lower() in link["href"].lower():
            # urljoin turns a relative link into a full web address
            return urljoin(response.url, link["href"])

    print(f"  No link containing '{pattern}' found on {page_url}")
    return None


def download(url: str, dest: Path) -> None:
    """Download url to dest in chunks, printing progress in MB."""
    with requests.get(url, headers=HEADERS, timeout=TIMEOUT, stream=True) as r:
        r.raise_for_status()
        total = 0
        with open(dest, "wb") as f:
            for chunk in r.iter_content(chunk_size=1024 * 1024):
                f.write(chunk)
                total += len(chunk)
                print(f"\r  Downloaded {total / 1e6:.1f} MB", end="")
    print()


def sha256(path: Path) -> str:
    """Fingerprint a file, so we can tell later whether the data changed."""
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def write_log(rows: list[dict]) -> None:
    """Append download records to data/raw/download_log.csv."""
    new_file = not LOG_PATH.exists()
    with open(LOG_PATH, "a", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        if new_file:
            writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    sources = yaml.safe_load(CONFIG_PATH.read_text())
    log_rows = []

    for name, src in sources.items():
        print(f"\n{name}: {src['description']}")

        # Work out the download address
        if "page_url" in src:
            url = find_link(src["page_url"], src["link_pattern"])
            if url is None:
                print("  Using fallback URL from the config file")
                url = src["fallback_url"]
        else:
            url = src["url"]
        print(f"  URL: {url}")

        # Download, then check we really got a ZIP and not an error page
        zip_path = RAW_DIR / f"{name}.zip"
        download(url, zip_path)
        if not zipfile.is_zipfile(zip_path):
            raise ValueError(
                f"{zip_path.name} is not a valid ZIP file. The server may have "
                "sent a web page instead (for example, a sign-in or form page)."
            )

        # Unzip into data/raw/<name>/
        out_dir = RAW_DIR / name
        with zipfile.ZipFile(zip_path) as z:
            z.extractall(out_dir)
        print(f"  Unzipped to data/raw/{name}/")

        log_rows.append({
            "dataset": name,
            "url": url,
            "downloaded_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "size_mb": round(zip_path.stat().st_size / 1e6, 2),
            "sha256": sha256(zip_path),
            "licence": src["licence"],
        })

    write_log(log_rows)
    print(f"\nDone. Download log: {LOG_PATH.relative_to(PROJECT_ROOT)}")


if __name__ == "__main__":
    main()