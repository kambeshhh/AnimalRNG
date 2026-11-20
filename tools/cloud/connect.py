#!/usr/bin/env python3
"""
Animal RNG — Cloud & Local Connector for Meshy AI, Headless Blender, and Roblox Open Cloud / Studio.

Place ID:    89511558428310
Universe ID: 10777840386

Environment variables:
  MESHY_API_KEY    — Meshy AI API key (https://api.meshy.ai)
  ROBLOX_API_KEY   — Roblox Open Cloud API key (Assets API + Luau Execution API)
  ROBLOX_USER_ID   — Creator User ID (default: 5101838508)
  BLENDER_BIN      — Path to blender executable (default: "blender")

Usage:
  python3 tools/cloud/connect.py status
  python3 tools/cloud/connect.py meshy-generate <CreatureName> "<prompt>"
  python3 tools/cloud/connect.py blender-process <CreatureName>
  python3 tools/cloud/connect.py roblox-upload <CreatureName> [--group Starter|Apex|Mythical|Cosmic]
  python3 tools/cloud/connect.py roblox-luau "<luau_code>"
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = REPO_ROOT / "assets" / "manifest.json"
PIPELINE_PY = REPO_ROOT / "tools" / "blender" / "pipeline.py"

PLACE_ID = os.environ.get("ROBLOX_PLACE_ID", "89511558428310")
UNIVERSE_ID = os.environ.get("ROBLOX_UNIVERSE_ID", "10777840386")
CREATOR_USER_ID = os.environ.get("ROBLOX_USER_ID", "5101838508")

DEFAULT_IMPORTS = REPO_ROOT / "build" / "imports" if os.name != "nt" else Path(r"C:\Users\admin\FrostbiteWolf\Imports")
DEFAULT_OUT = REPO_ROOT / "build" / "out" if os.name != "nt" else Path(r"C:\Users\admin\FrostbiteWolf\GameAssets\New")


def http_json(url: str, method: str = "GET", headers: dict | None = None, payload: dict | None = None) -> dict:
    req_headers = {"Accept": "application/json"}
    if headers:
        req_headers.update(headers)
    data = None
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        req_headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=req_headers, method=method)
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read().decode("utf-8"))


def cmd_status(_args: argparse.Namespace) -> int:
    meshy_key = bool(os.environ.get("MESHY_API_KEY"))
    roblox_key = bool(os.environ.get("ROBLOX_API_KEY"))
    blender_bin = os.environ.get("BLENDER_BIN") or shutil.which("blender")
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    print("=== Animal RNG Pipeline Connector Status ===")
    print(f"Place / Universe : {PLACE_ID} / {UNIVERSE_ID}")
    print(f"Manifest Models  : {len(manifest)} creatures ({MANIFEST_PATH.relative_to(REPO_ROOT)})")
    print(f"MESHY_API_KEY    : {'CONNECTED' if meshy_key else 'NOT SET (export MESHY_API_KEY=msy_...)'}")
    print(f"ROBLOX_API_KEY   : {'CONNECTED' if roblox_key else 'NOT SET (export ROBLOX_API_KEY=...)'}")
    print(f"Blender Binary   : {blender_bin or 'NOT FOUND in PATH (set BLENDER_BIN)'}")
    return 0


def cmd_meshy_generate(args: argparse.Namespace) -> int:
    api_key = os.environ.get("MESHY_API_KEY")
    if not api_key:
        print("Error: MESHY_API_KEY environment variable is required.", file=sys.stderr)
        return 1
    headers = {"Authorization": f"Bearer {api_key}"}
    print(f"[Meshy] Creating text-to-3d preview task for {args.name}...")
    preview = http_json(
        "https://api.meshy.ai/openapi/v2/text-to-3d",
        method="POST",
        headers=headers,
        payload={
            "mode": "preview",
            "prompt": args.prompt,
            "art_style": "sculpture",
            "should_remesh": True,
        },
    )
    preview_id = preview["result"]
    while True:
        task = http_json(f"https://api.meshy.ai/openapi/v2/text-to-3d/{preview_id}", headers=headers)
        status = task.get("status")
        print(f"[Meshy] Preview {preview_id}: {status} ({task.get('progress', 0)}%)")
        if status == "SUCCEEDED":
            break
        if status in ("FAILED", "CANCELED"):
            raise RuntimeError(f"Meshy preview failed: {task}")
        time.sleep(10)

    print(f"[Meshy] Creating refine task for {args.name}...")
    refine = http_json(
        "https://api.meshy.ai/openapi/v2/text-to-3d",
        method="POST",
        headers=headers,
        payload={"mode": "refine", "preview_task_id": preview_id},
    )
    refine_id = refine["result"]
    while True:
        task = http_json(f"https://api.meshy.ai/openapi/v2/text-to-3d/{refine_id}", headers=headers)
        status = task.get("status")
        print(f"[Meshy] Refine {refine_id}: {status} ({task.get('progress', 0)}%)")
        if status == "SUCCEEDED":
            break
        if status in ("FAILED", "CANCELED"):
            raise RuntimeError(f"Meshy refine failed: {task}")
        time.sleep(10)

    dest_dir = Path(os.environ.get("MESHY_IMPORTS_DIR", str(DEFAULT_IMPORTS))) / args.name
    dest_dir.mkdir(parents=True, exist_ok=True)
    fbx_url = task["model_urls"]["fbx"]
    tex_url = (task.get("texture_urls") or [{}])[0].get("base_color")
    urllib.request.urlretrieve(fbx_url, dest_dir / "model.fbx")
    if tex_url:
        urllib.request.urlretrieve(tex_url, dest_dir / "model.png")
    print(f"[Meshy] Downloaded {args.name} to {dest_dir}")
    return 0


def cmd_blender_process(args: argparse.Namespace) -> int:
    blender_bin = os.environ.get("BLENDER_BIN") or shutil.which("blender")
    if not blender_bin:
        print("Error: Blender executable not found. Set BLENDER_BIN.", file=sys.stderr)
        return 1
    env = os.environ.copy()
    env.setdefault("MESHY_IMPORTS_DIR", str(DEFAULT_IMPORTS))
    env.setdefault("BLENDER_OUT_DIR", str(DEFAULT_OUT))
    cmd = [blender_bin, "-b", "-P", str(PIPELINE_PY), "--", *args.names]
    print("[Blender] Running:", " ".join(cmd))
    return subprocess.call(cmd, env=env)


def cmd_roblox_luau(args: argparse.Namespace) -> int:
    api_key = os.environ.get("ROBLOX_API_KEY")
    if not api_key:
        print("Error: ROBLOX_API_KEY environment variable is required.", file=sys.stderr)
        return 1
    headers = {"x-api-key": api_key}
    url = f"https://apis.roblox.com/cloud/v2/universes/{UNIVERSE_ID}/places/{PLACE_ID}/luau-execution-session-tasks"
    task = http_json(url, method="POST", headers=headers, payload={"script": args.script})
    task_path = task["path"]
    poll_url = f"https://apis.roblox.com/cloud/v2/{task_path}"
    while True:
        info = http_json(poll_url, headers=headers)
        state = info.get("state")
        print(f"[Roblox Cloud] Task state: {state}")
        if state in ("COMPLETE", "FAILED", "CANCELLED"):
            print(json.dumps(info, indent=2))
            return 0 if state == "COMPLETE" else 1
        time.sleep(3)


def main() -> int:
    parser = argparse.ArgumentParser(description="Animal RNG Meshy / Blender / Roblox Cloud Connector")
    sub = parser.add_subparsers(dest="command", required=True)

    p_status = sub.add_parser("status", help="Show connection status for Meshy AI, Blender, and Roblox Open Cloud")
    p_status.set_defaults(func=cmd_status)

    p_meshy = sub.add_parser("meshy-generate", help="Generate and download a 3D creature via Meshy AI")
    p_meshy.add_argument("name", help="Creature key (e.g. CelestialUnicorn)")
    p_meshy.add_argument("prompt", help="Meshy text-to-3D prompt")
    p_meshy.set_defaults(func=cmd_meshy_generate)

    p_blender = sub.add_parser("blender-process", help="Run headless Blender pipeline on imported models")
    p_blender.add_argument("names", nargs="+", help="Creature names in pipeline.py SPEC")
    p_blender.set_defaults(func=cmd_blender_process)

    p_luau = sub.add_parser("roblox-luau", help="Execute Luau in Roblox Open Cloud for Animal RNG")
    p_luau.add_argument("script", help="Luau code to execute")
    p_luau.set_defaults(func=cmd_roblox_luau)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
