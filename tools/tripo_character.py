"""Tripo3D pipeline: image -> textured model -> biped rig (mixamo) -> animations -> GLB files.

Usage:
    set TRIPO_API_KEY=tsk_...            (PowerShell: $env:TRIPO_API_KEY="tsk_...")
    python tools/tripo_character.py <image.png> <out_dir> [--name altushka] [--anims walk,idle,run]

Docs: https://developers.tripo3d.ai/ru/docs/quick-start  (API v3)
"""
import argparse
import os
import sys
import time

import requests

BASE = "https://openapi.tripo3d.ai/v3"
GEN_MODEL = "v3.1-20260211"
RIG_MODEL = "v3.0-20260909"
FAILED = {"failed", "cancelled", "banned", "expired"}


def headers(json=True):
    key = os.environ.get("TRIPO_API_KEY")
    if not key:
        sys.exit("TRIPO_API_KEY is not set")
    h = {"Authorization": f"Bearer {key}"}
    if json:
        h["Content-Type"] = "application/json"
    return h


def check(r):
    if not r.ok:
        raise RuntimeError(f"HTTP {r.status_code}: {r.text}")
    body = r.json()
    if body.get("code") != 0:
        raise RuntimeError(f"Tripo error: {body}")
    return body["data"]


def upload(path):
    with open(path, "rb") as f:
        return check(requests.post(f"{BASE}/files", headers=headers(False), files={"file": f}))["file_token"]


def create(endpoint, body):
    data = check(requests.post(f"{BASE}/{endpoint}", headers=headers(), json=body))
    print(f"  task {endpoint}: {data['task_id']}")
    return data["task_id"]


def wait(task_id):
    while True:
        data = check(requests.get(f"{BASE}/tasks/{task_id}", headers=headers(False)))
        st = data["status"]
        print(f"    {st} {data.get('progress', 0)}%", end="\r")
        if st == "success":
            print()
            return data["output"]
        if st in FAILED:
            raise RuntimeError(f"task {task_id} {st}: {data}")
        time.sleep(2.5)


def download(url, path):
    # URLs expire after 5 minutes: download immediately
    r = requests.get(url, timeout=300)
    r.raise_for_status()
    with open(path, "wb") as f:
        f.write(r.content)
    print(f"  saved {path} ({len(r.content) // 1024} KB)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("out_dir")
    ap.add_argument("--name", default="character")
    ap.add_argument("--anims", default="idle,walk,run")
    ap.add_argument("--faces", type=int, default=20000)
    a = ap.parse_args()
    os.makedirs(a.out_dir, exist_ok=True)

    print("1) upload image")
    token = upload(a.image)

    print("2) image -> model")
    gen = create("generation/image-to-model", {
        "input": token, "model": GEN_MODEL, "face_limit": a.faces,
        "texture": True, "pbr": True, "texture_quality": "detailed",
        "geometry_quality": "detailed", "auto_size": True,
        "enable_image_autofix": True,
    })
    out = wait(gen)
    download(out["model_url"], os.path.join(a.out_dir, f"{a.name}_static.glb"))
    if out.get("rendered_image_url"):
        download(out["rendered_image_url"], os.path.join(a.out_dir, f"{a.name}_preview.webp"))

    print("3) rig check")
    rc = wait(create("animations/rig-check", {"input": gen}))
    print(f"  {rc}")
    if not rc.get("riggable", True):
        sys.exit("model is not riggable; static GLB saved")

    print("4) rig (biped, mixamo bone names)")
    rig = create("animations/rig", {"input": gen, "model": RIG_MODEL,
                                     "rig_type": rc.get("rig_type", "biped"), "spec": "mixamo"})
    download(wait(rig)["model_url"], os.path.join(a.out_dir, f"{a.name}_rigged.glb"))

    for anim in filter(None, a.anims.split(",")):
        print(f"5) animation {anim}")
        try:
            t = create("animations/retarget", {"input": rig, "animation": f"preset:{anim}"})
            download(wait(t)["model_url"], os.path.join(a.out_dir, f"{a.name}_{anim}.glb"))
        except Exception as e:  # keep going if one preset name is wrong
            print(f"  skipped {anim}: {e}")

    print("done")


if __name__ == "__main__":
    main()
