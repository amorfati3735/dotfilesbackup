#!/usr/bin/env python3
"""Gently probe every NVIDIA NIM model with a tiny chat request.

Usage:
    ./nim-probe.py                # probe all models
    ./nim-probe.py --delay 2.0    # custom delay (seconds) between requests
    ./nim-probe.py --resume       # skip models already in the results file
    ./nim-probe.py --workers 1    # serial (default) -- raise carefully

Reads NVIDIA_API_KEY from env. Writes results to ~/Downloads/amp/nim-probe.json
and prints a final list of working chat models.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path

import urllib.request
import urllib.error

API_BASE = "https://integrate.api.nvidia.com/v1"
RESULTS = Path.home() / "Downloads" / "amp" / "nim-probe.json"


def http_json(method: str, url: str, key: str, body: dict | None = None, timeout: int = 30):
    data = None
    headers = {"Authorization": f"Bearer {key}", "Accept": "application/json"}
    if body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status, json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        try:
            payload = json.loads(e.read().decode())
        except Exception:
            payload = {"error": str(e)}
        return e.code, payload
    except Exception as e:
        return 0, {"error": f"{type(e).__name__}: {e}"}


def list_models(key: str) -> list[str]:
    status, payload = http_json("GET", f"{API_BASE}/models", key)
    if status != 200:
        print(f"failed to list models: {status} {payload}", file=sys.stderr)
        sys.exit(1)
    return sorted(m["id"] for m in payload["data"])


def probe(model: str, key: str) -> tuple[bool, int, str]:
    """Send a tiny chat completion. Returns (ok, status, note)."""
    body = {
        "model": model,
        "messages": [{"role": "user", "content": "hi"}],
        "max_tokens": 1,
        "temperature": 0,
        "stream": False,
    }
    status, payload = http_json("POST", f"{API_BASE}/chat/completions", key, body)
    if status == 200 and "choices" in payload:
        return True, status, "ok"
    err = payload.get("error") or payload.get("detail") or payload
    if isinstance(err, dict):
        err = err.get("message") or json.dumps(err)[:200]
    return False, status, str(err)[:200]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--delay", type=float, default=1.5, help="seconds between requests")
    ap.add_argument("--resume", action="store_true", help="skip models in existing results")
    ap.add_argument("--limit", type=int, default=0, help="probe only N models (0=all)")
    args = ap.parse_args()

    key = os.environ.get("NVIDIA_API_KEY")
    if not key:
        print("NVIDIA_API_KEY not set", file=sys.stderr)
        return 1

    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    existing: dict[str, dict] = {}
    if args.resume and RESULTS.exists():
        try:
            existing = json.loads(RESULTS.read_text()).get("results", {})
        except Exception:
            existing = {}

    models = list_models(key)
    if args.limit:
        models = models[: args.limit]

    print(f"probing {len(models)} models (delay={args.delay}s, resume={args.resume})")
    results: dict[str, dict] = dict(existing)
    rate_limited = 0

    for i, model in enumerate(models, 1):
        if args.resume and model in existing and existing[model].get("status") not in (0, 429, 503, 504):
            continue

        ok, status, note = probe(model, key)
        results[model] = {"ok": ok, "status": status, "note": note, "ts": time.time()}
        marker = "✓" if ok else "✗"
        print(f"[{i:>3}/{len(models)}] {marker} {status:>3} {model}  {note if not ok else ''}".rstrip())

        # Persist incrementally so a Ctrl+C doesn't lose progress
        RESULTS.write_text(json.dumps({"results": results}, indent=2))

        # Backoff on rate limit / overload
        if status == 429:
            rate_limited += 1
            backoff = min(60, 5 * rate_limited)
            print(f"   -> 429 hit, sleeping {backoff}s")
            time.sleep(backoff)
        elif status in (503, 504):
            time.sleep(5)
        else:
            rate_limited = max(0, rate_limited - 1)
            time.sleep(args.delay)

    working = sorted(m for m, r in results.items() if r["ok"])
    print()
    print("=" * 60)
    print(f"WORKING CHAT MODELS ({len(working)}):")
    print("=" * 60)
    for m in working:
        print(f"  {m}")
    print()
    print(f"results saved to {RESULTS}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
