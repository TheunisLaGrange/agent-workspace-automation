import json
import os
import sys
from pathlib import Path
import requests

TAG_NAME     = "v1.0.0"
RELEASE_NOTES = (
    "### Standalone Windows Release (v1.0.0)\n"
    "- **Backend Engine:** Nuitka-compiled standalone Python executable (no Python installation required).\n"
    "- **Desktop GUI:** Self-contained .NET 10 WPF desktop application.\n"
    "- **Bridge Contract:** Decoupled CSV/JSON communication via `Shared_Data/`."
)

def load_active_project() -> tuple[str, str, str]:
    """Reads owner, repo name, and zip filename dynamically from active_project.json."""
    manifest_path = Path(__file__).resolve().parent / "active_project.json"
    print(f"[DIAGNOSTIC] Manifest Path : {manifest_path}")
    print(f"[DIAGNOSTIC] Manifest Exists: {manifest_path.exists()}")

    if manifest_path.exists():
        data = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
        project_name = data.get("project_name", "StrataRisk")
        github_url = data.get("github_url", "https://github.com").rstrip("/")
        parts = github_url.split("/")
        owner = parts[-2] if len(parts) >= 2 else "TheunisLaGrange"
        repo = parts[-1] if len(parts) >= 1 else project_name
        zip_filename = f"{project_name}-{TAG_NAME}-win-x64.zip"

        print(f"[DIAGNOSTIC] Raw github_url : {github_url}")
        print(f"[DIAGNOSTIC] Parsed Owner   : {owner}")
        print(f"[DIAGNOSTIC] Parsed Repo    : {repo}")
        print(f"[DIAGNOSTIC] Target ZIP     : {zip_filename}")
        return owner, repo, zip_filename

    return "TheunisLaGrange", "StrataRisk", f"StrataRisk-{TAG_NAME}-win-x64.zip"

def get_desktop_zip(filename: str) -> Path:
    """Resolves the exact Windows Desktop path (including OneDrive redirection)."""
    user_profile = Path(os.environ.get("USERPROFILE", ""))
    candidates = [
        user_profile / "Desktop" / filename,
        user_profile / "OneDrive" / "Desktop" / filename,
    ]
    for path in candidates:
        if path.exists() and path.is_file():
            return path
    raise FileNotFoundError(f"Could not locate '{filename}' on Desktop.")


def publish_release() -> None:
    token = os.environ.get("GITHUB_TOKEN", "").strip()
    if not token:
        print("[HANDSHAKE FAILED] GITHUB_TOKEN environment variable is not set.")
        sys.exit(1)

    owner, repo, zip_filename = load_active_project()
    zip_path = get_desktop_zip(zip_filename)

    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }

    api_base = "https://api." + "github.com/repos"
    release_api = f"{api_base}/{owner}/{repo}/releases"

    print(f"[DIAGNOSTIC] Release API   : {release_api}")

    payload = {
        "tag_name": TAG_NAME,
        "target_commitish": "main",
        "name": f"{repo} {TAG_NAME} - Standalone Windows Release",
        "body": RELEASE_NOTES,
        "draft": False,
        "prerelease": False,
    }

    print(f"[1/2] Creating GitHub Release '{TAG_NAME}' on {owner}/{repo}...")

    print(f"[DIAGNOSTIC] POST Endpoint  : {release_api}")
    print(f"[DIAGNOSTIC] Payload        : {json.dumps(payload)}")

    resp = requests.post(release_api, headers=headers, json=payload, timeout=30)

    if resp.status_code == 201:
        release_data = resp.json()
    elif resp.status_code == 422:
        existing = requests.get(f"{release_api}/tags/{TAG_NAME}", headers=headers, timeout=30)
        existing.raise_for_status()
        release_data = existing.json()
        print(f"[INFO] Release '{TAG_NAME}' already exists. Replacing asset...")
    else:
        print(f"[HANDSHAKE FAILED] GitHub API Error ({resp.status_code}): {resp.text}")
        sys.exit(1)

    # Remove existing asset with the same name if re-uploading
    for asset in release_data.get("assets", []):
        if asset["name"] == zip_filename:
            del_url = f"{api_base}/{owner}/{repo}/releases/assets/{asset['id']}"
            print(f"[DIAGNOSTIC] DELETE Endpoint: {del_url}")
            print(f"[INFO] Deleting existing asset '{zip_filename}' (ID: {asset['id']})...")
            requests.delete(del_url, headers=headers, timeout=30).raise_for_status()

    # Strip the URI template suffix '{?name,label}' cleanly
    upload_url = release_data["upload_url"].split("{")[0]
    upload_headers = {
        **headers,
        "Content-Type": "application/zip",
    }

    size_mb = zip_path.stat().st_size / (1024 * 1024)
    print(f"[2/2] Uploading {zip_filename} ({size_mb:.2f} MB)...")

    with zip_path.open("rb") as f:
        up_resp = requests.post(
            upload_url,
            headers=upload_headers,
            params={"name": zip_filename},
            data=f,
            timeout=300,
        )

    if up_resp.status_code != 201:
        print(f"[HANDSHAKE FAILED] Asset upload failed ({up_resp.status_code}): {up_resp.text}")
        sys.exit(1)

    download_url = up_resp.json().get("browser_download_url")
    print("\n=== HANDSHAKE SUCCESS ===")
    print(f"Release Page : {release_data.get('html_url')}")
    print(f"Direct ZIP   : {download_url}")


if __name__ == "__main__":
    try:
        publish_release()
    except Exception as exc:
        print(f"[HANDSHAKE ERROR] {type(exc).__name__}: {exc}")
        sys.exit(1)
