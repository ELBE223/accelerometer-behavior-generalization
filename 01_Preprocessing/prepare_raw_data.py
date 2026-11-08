# prepare_raw_data.py
#
# Purpose:
# - Horse_dataset_2: downloads the original public dataset (Horsing Around,
#   4TU.ResearchData) into data/raw/Horse_dataset_2/original_download/ and
#   unpacks archives into original_download/extracted/ (without the MATLAB copies of
#   the CSV data). An archive copied into original_download/ by hand is used instead
#   of a download.
# - Horse_dataset_2 and Dog_dataset_2: moves the files that were converted for the
#   thesis (not raw data) into converted_thesis/, so the raw folders hold raw data only.
# - Safe to run again: finished downloads, extracted archives and moved files are skipped;
#   an interrupted download is resumed.
#
# Usage (from the project folder, venv active):
#   python 01_Preprocessing/prepare_raw_data.py
#
# If the 4TU file list cannot be read, the script names the page to download the files
# from by hand; put them into original_download/ and run the script again.

from __future__ import annotations

import hashlib
import json
import re
import shutil
import time
import urllib.error
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = ROOT / "data" / "raw"

HORSE_DIR = RAW_DIR / "Horse_dataset_2"
HORSE_DOWNLOAD_DIR = HORSE_DIR / "original_download"
HORSE_EXTRACT_DIR = HORSE_DOWNLOAD_DIR / "extracted"
HORSE_DOI = "10.4121/uuid:2e08745c-4178-4183-8551-f248c992cb14"
HORSE_UUID = "2e08745c-4178-4183-8551-f248c992cb14"
FOURTU_FILES_API = "https://data.4tu.nl/v2/articles/{id}/files"

# Thesis-converted files: (dataset, folder with the converted files, file pattern).
CONVERTED = [
    ("Horse_dataset_2", "Data_Horse_Raw", "*.parquet"),
    ("Dog_dataset_2", "Data_Dog_Proccessed", "*.parquet"),
]
CONVERTED_DIR_NAME = "converted_thesis"

USER_AGENT = "paper-izw-cross-species-transfer/1.0 (research data download)"
CHUNK_BYTES = 1024 * 1024
PROGRESS_BYTES = 100 * 1024 * 1024
FREE_SPACE_FACTOR = 2.2  # archive + extracted files, with some margin
ARCHIVE_SUFFIXES = (".zip", ".tar", ".tar.gz", ".tgz", ".tar.bz2", ".tar.xz")
# The Horsing Around download holds the same data as CSV and as MATLAB files; only CSV is used.
EXTRACT_SKIP_PREFIXES = ("matlab/", "__MACOSX/")
EXTRACT_DONE_MARKER = ".extracted_complete"


# =========================================================
# Helpers
# =========================================================
def log(msg: str) -> None:
    print(msg, flush=True)


def fmt_size(n_bytes: float) -> str:
    for unit in ["B", "KB", "MB", "GB"]:
        if n_bytes < 1024 or unit == "GB":
            return f"{n_bytes:.1f} {unit}"
        n_bytes /= 1024
    return ""


def request(url: str, headers: dict | None = None) -> urllib.request.Request:
    return urllib.request.Request(url, headers={"User-Agent": USER_AGENT, **(headers or {})})


def get_json(url: str):
    with urllib.request.urlopen(request(url, {"Accept": "application/json"}), timeout=60) as resp:
        return json.load(resp)


def md5_of(path: Path) -> str:
    digest = hashlib.md5()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(CHUNK_BYTES), b""):
            digest.update(chunk)
    return digest.hexdigest()


# =========================================================
# Converted thesis files
# =========================================================
def move_converted_files() -> None:
    for dataset, folder, pattern in CONVERTED:
        src = RAW_DIR / dataset / folder
        dst = RAW_DIR / dataset / CONVERTED_DIR_NAME
        files = [p for p in sorted(src.glob(pattern)) if not p.name.startswith("._")] if src.is_dir() else []
        if not files:
            log(f"[SKIP] {dataset}: no converted files left in {folder}/")
            continue
        dst.mkdir(exist_ok=True)
        for p in files:
            shutil.move(str(p), str(dst / p.name))
            # macOS metadata file of the moved file, if any.
            (src / f"._{p.name}").unlink(missing_ok=True)
        log(f"[OK] {dataset}: {len(files)} converted file(s) moved to {CONVERTED_DIR_NAME}/")


# =========================================================
# Horse_dataset_2 download
# =========================================================
def find_horse_files() -> tuple[list[dict], str]:
    # Returns the 4TU file list and the landing page of the dataset.
    landing = f"https://doi.org/{HORSE_DOI}"
    candidates = [HORSE_UUID]
    try:
        with urllib.request.urlopen(request(landing), timeout=60) as resp:
            landing = resp.geturl()
        log(f"[INFO] DOI resolves to {landing}")
        candidates += re.findall(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", landing)
        candidates += re.findall(r"/(\d{6,})(?=/|$)", landing)
    except (urllib.error.URLError, OSError) as exc:
        log(f"[WARN] DOI could not be resolved: {exc}")

    for candidate in dict.fromkeys(candidates):
        url = FOURTU_FILES_API.format(id=candidate)
        try:
            files = get_json(url)
        except (urllib.error.URLError, OSError, ValueError) as exc:
            log(f"[INFO] No file list from {url}: {exc}")
            continue
        files = [f for f in files if isinstance(f, dict) and f.get("download_url") and not f.get("is_link_only")]
        if files:
            return files, landing
    return [], landing


def download(url: str, dest: Path, size: int | None) -> None:
    part = dest.with_name(dest.name + ".part")
    done = part.stat().st_size if part.exists() else 0
    headers = {"Range": f"bytes={done}-"} if done else {}
    with urllib.request.urlopen(request(url, headers), timeout=120) as resp:
        if done and resp.status != 206:
            done = 0  # server ignored the range request: start again
        mode = "ab" if done else "wb"
        if done:
            log(f"[INFO] Resuming {dest.name} at {fmt_size(done)}")
        next_report = done + PROGRESS_BYTES
        with part.open(mode) as fh:
            for chunk in iter(lambda: resp.read(CHUNK_BYTES), b""):
                fh.write(chunk)
                done += len(chunk)
                if done >= next_report:
                    total = f" of {fmt_size(size)}" if size else ""
                    log(f"[INFO] {dest.name}: {fmt_size(done)}{total}")
                    next_report += PROGRESS_BYTES
    if size is not None and part.stat().st_size != size:
        raise RuntimeError(f"{dest.name}: size {part.stat().st_size} differs from {size}; run the script again")
    part.replace(dest)


def download_horse_dataset() -> bool:
    HORSE_DOWNLOAD_DIR.mkdir(parents=True, exist_ok=True)
    # Downloaded or copied files present (an interrupted download leaves only .part files):
    # no need to contact 4TU.
    present = [p for p in HORSE_DOWNLOAD_DIR.iterdir()
               if p.is_file() and not p.name.startswith(".") and not p.name.endswith(".part")]
    if present and not any(p.name.endswith(".part") for p in HORSE_DOWNLOAD_DIR.iterdir()):
        log(f"[SKIP] original_download/ holds {len(present)} file(s); no download")
        return True
    files, landing = find_horse_files()
    if not files:
        existing = [p for p in HORSE_DOWNLOAD_DIR.rglob("*")
                    if p.is_file() and not p.name.startswith(".") and not p.name.endswith(".part")]
        if existing:
            log(f"[INFO] File list not available; using the {len(existing)} file(s) already in original_download/")
            return True
        log("[ERROR] The 4TU file list could not be read. Download the files by hand from")
        log(f"        {landing}")
        log(f"        into {HORSE_DOWNLOAD_DIR.relative_to(ROOT)}/ and run this script again.")
        return False

    # Original files copied by hand replace the download.
    names = {Path(f["name"]).name for f in files}
    # Also in subfolders (e.g. a copied csv/ folder), but not the unpacked download.
    existing = {p.name for p in HORSE_DOWNLOAD_DIR.rglob("*")
                if p.is_file() and not p.name.startswith(".") and not p.name.endswith(".part")
                and HORSE_EXTRACT_DIR not in p.parents}
    if existing and not existing & names:
        log(f"[SKIP] original_download/ holds {len(existing)} file(s) not from the 4TU list (copied by hand?); no download")
        return True

    total = sum(int(f.get("size") or 0) for f in files)
    free = shutil.disk_usage(HORSE_DOWNLOAD_DIR).free
    log(f"[INFO] Horsing Around: {len(files)} file(s), {fmt_size(total)}; free space {fmt_size(free)}")
    if total and free < FREE_SPACE_FACTOR * total:
        log(f"[ERROR] Not enough free space (needed about {fmt_size(FREE_SPACE_FACTOR * total)})")
        return False

    for f in files:
        dest = HORSE_DOWNLOAD_DIR / Path(f["name"]).name
        size = int(f["size"]) if f.get("size") else None
        md5 = f.get("computed_md5") or f.get("supplied_md5")
        if dest.exists() and (size is None or dest.stat().st_size == size):
            log(f"[SKIP] {dest.name} already downloaded")
            continue
        log(f"[INFO] Downloading {dest.name} ({fmt_size(size) if size else 'size unknown'})")
        start = time.time()
        download(f["download_url"], dest, size)
        log(f"[OK] {dest.name} ({time.time() - start:.0f} s)")
        # Checked once after the download; later runs rely on the file size.
        if md5:
            if md5_of(dest) != md5:
                dest.unlink()
                raise RuntimeError(f"{dest.name}: checksum differs; file deleted, run the script again")
            log(f"[OK] {dest.name}: checksum verified")
    return True


def extract_zip(archive: Path, target: Path) -> None:
    with zipfile.ZipFile(archive) as zf:
        members = [m for m in zf.infolist()
                   if not m.filename.startswith(EXTRACT_SKIP_PREFIXES) and "/._" not in f"/{m.filename}"]
        total = sum(m.file_size for m in members)
        log(f"[INFO] {len(members)} entries, {fmt_size(total)} (skipped: {', '.join(EXTRACT_SKIP_PREFIXES)})")
        done = 0
        next_report = PROGRESS_BYTES * 10
        for m in members:
            zf.extract(m, target)
            done += m.file_size
            if done >= next_report:
                log(f"[INFO] {archive.name}: {fmt_size(done)} of {fmt_size(total)} extracted")
                next_report += PROGRESS_BYTES * 10


def extract_archives() -> None:
    archives = [p for p in sorted(HORSE_DOWNLOAD_DIR.iterdir())
                if p.is_file() and not p.name.startswith(".") and p.name.lower().endswith(ARCHIVE_SUFFIXES)]
    for archive in archives:
        target = HORSE_EXTRACT_DIR / archive.name.split(".")[0]
        # Written last, so an interrupted extraction is repeated.
        marker = target / EXTRACT_DONE_MARKER
        if marker.exists():
            log(f"[SKIP] {archive.name} already extracted")
            continue
        target.mkdir(parents=True, exist_ok=True)
        log(f"[INFO] Extracting {archive.name}")
        if archive.name.lower().endswith(".zip"):
            extract_zip(archive, target)
        else:
            shutil.unpack_archive(str(archive), str(target))
        marker.write_text(f"extracted from {archive.name} on {time.strftime('%Y-%m-%d %H:%M:%S')}\n", encoding="utf-8")
        log(f"[OK] {archive.name} extracted to {target.relative_to(ROOT)}/")


# =========================================================
# Main
# =========================================================
def main() -> int:
    move_converted_files()
    if not download_horse_dataset():
        return 1
    extract_archives()
    log("[OK] Raw data prepared")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
