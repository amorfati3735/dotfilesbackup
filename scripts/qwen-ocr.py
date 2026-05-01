#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "httpx>=0.27",
#   "pypdfium2>=4.30",
#   "openai>=1.40",
#   "rich>=13",
# ]
# ///
"""
qocr — fast PDF / image OCR to Markdown.

Default backend: Mistral OCR (cloud, native PDF, generous free tier).
Optional backend: LM Studio (local Qwen3-VL via OpenAI-compatible API).

Usage:
    qocr input.pdf                      # → input.md
    qocr scan.png -o out.md
    qocr doc.pdf --pages 1,3-5
    qocr doc.pdf --provider lmstudio    # local Qwen3-VL via LM Studio
    qocr doc.pdf --provider mistral --model mistral-ocr-2512

Env:
    MISTRAL_API_KEY       required for --provider mistral (default)
    QWEN_OCR_HOST         LM Studio base URL (default http://localhost:1234/v1)
    QWEN_OCR_MODEL        LM Studio model id (default qwen3-vl-4b)
"""

from __future__ import annotations

import argparse
import base64
import io
import os
import sys
from pathlib import Path

import httpx
import pypdfium2 as pdfium
from rich.console import Console
from rich.progress import (
    BarColumn,
    Progress,
    SpinnerColumn,
    TextColumn,
    TimeElapsedColumn,
)

console = Console()

# ──────────────────────────────────────────────────────────────────────────────
# Mistral OCR backend (default)
# https://docs.mistral.ai/capabilities/document/
# ──────────────────────────────────────────────────────────────────────────────

MISTRAL_URL = "https://api.mistral.ai/v1/ocr"


def mistral_ocr(path: Path, model: str, pages: list[int] | None) -> str:
    api_key = os.environ.get("MISTRAL_API_KEY")
    if not api_key:
        console.print("[red]MISTRAL_API_KEY not set.[/red] "
                      "Add to ~/.env_secrets and `source` your shell.")
        sys.exit(2)

    suffix = path.suffix.lower()
    data = base64.b64encode(path.read_bytes()).decode()
    if suffix == ".pdf":
        document = {"type": "document_url",
                    "document_url": f"data:application/pdf;base64,{data}"}
    elif suffix in {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tiff", ".tif"}:
        mime = {"jpg": "jpeg", "tif": "tiff"}.get(suffix.lstrip("."), suffix.lstrip("."))
        document = {"type": "image_url",
                    "image_url": f"data:image/{mime};base64,{data}"}
    else:
        console.print(f"[red]unsupported file type:[/red] {suffix}")
        sys.exit(1)

    payload: dict = {"model": model, "document": document, "include_image_base64": False}
    if pages is not None:
        # Mistral uses 0-indexed pages
        payload["pages"] = [p - 1 for p in pages]

    with console.status(f"[cyan]Mistral OCR[/cyan] {path.name} …"):
        with httpx.Client(timeout=600) as client:
            r = client.post(
                MISTRAL_URL,
                headers={"Authorization": f"Bearer {api_key}",
                         "Content-Type": "application/json"},
                json=payload,
            )
    if r.status_code != 200:
        console.print(f"[red]Mistral API {r.status_code}:[/red] {r.text[:500]}")
        sys.exit(1)

    body = r.json()
    out: list[str] = []
    for page in body.get("pages", []):
        idx = page.get("index", 0) + 1  # back to 1-indexed for the marker
        md = page.get("markdown", "").strip()
        out.append(f"<!-- page {idx} -->\n\n{md}")
    return "\n\n".join(out) + "\n"


# ──────────────────────────────────────────────────────────────────────────────
# LM Studio / OpenAI-compatible backend (local fallback)
# ──────────────────────────────────────────────────────────────────────────────

LMSTUDIO_PROMPT = """You are an OCR engine. Extract the content of this document page as clean Markdown.

Rules:
- Preserve heading hierarchy, lists, tables, code blocks, and blockquotes.
- Render math in LaTeX: inline $...$, display $$...$$.
- Tables → GitHub-flavored Markdown.
- Keep reading order (multi-column → linearized).
- Output only the document content (no commentary).
- If the page is blank, output exactly: <!-- empty page -->
"""


def parse_pages(spec: str | None, total: int) -> list[int]:
    if not spec:
        return list(range(1, total + 1))
    pages: set[int] = set()
    for chunk in spec.split(","):
        chunk = chunk.strip()
        if not chunk:
            continue
        if "-" in chunk:
            a, b = chunk.split("-", 1)
            pages.update(range(int(a), int(b) + 1))
        else:
            pages.add(int(chunk))
    return sorted(p for p in pages if 1 <= p <= total)


def lmstudio_ocr(path: Path, model: str, host: str, dpi: int,
                 pages_spec: str | None) -> str:
    from openai import OpenAI

    client = OpenAI(base_url=host, api_key="lm-studio")
    try:
        client.models.list()
    except Exception as e:
        console.print(f"[red]cannot reach LM Studio[/red] {host}\n  {e}")
        console.print("[yellow]hint:[/yellow] start LM Studio → Developer → "
                      "Start Server, and load Qwen3-VL.")
        sys.exit(2)

    suffix = path.suffix.lower()
    images: list[tuple[int, bytes]] = []
    if suffix == ".pdf":
        pdf = pdfium.PdfDocument(str(path))
        targets = parse_pages(pages_spec, len(pdf))
        for n in targets:
            page = pdf[n - 1]
            img = page.render(scale=dpi / 72).to_pil()
            buf = io.BytesIO()
            img.save(buf, format="PNG", optimize=True)
            images.append((n, buf.getvalue()))
        pdf.close()
    else:
        images.append((1, path.read_bytes()))

    parts: list[str] = []
    with Progress(
        SpinnerColumn(),
        TextColumn("[bold]{task.description}"),
        BarColumn(),
        TextColumn("{task.completed}/{task.total}"),
        TimeElapsedColumn(),
        console=console,
    ) as progress:
        task = progress.add_task(f"OCR {path.name}", total=len(images))
        for page_no, png in images:
            b64 = base64.b64encode(png).decode()
            resp = client.chat.completions.create(
                model=model,
                messages=[{
                    "role": "user",
                    "content": [
                        {"type": "text", "text": LMSTUDIO_PROMPT},
                        {"type": "image_url",
                         "image_url": {"url": f"data:image/png;base64,{b64}"}},
                    ],
                }],
                temperature=0.1,
                max_tokens=8192,
            )
            text = (resp.choices[0].message.content or "").strip()
            parts.append(f"<!-- page {page_no} -->\n\n{text}")
            progress.advance(task)
    return "\n\n".join(parts) + "\n"


# ──────────────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────────────


def main() -> int:
    ap = argparse.ArgumentParser(
        description="PDF / image OCR → Markdown (Mistral OCR by default)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    ap.add_argument("input", type=Path, help="PDF or image file")
    ap.add_argument("-o", "--output", type=Path, help="output .md (default: <input>.md)")
    ap.add_argument("--provider", choices=["mistral", "lmstudio"], default="mistral",
                    help="OCR backend (default: mistral)")
    ap.add_argument("--model",
                    help="model id; defaults: mistral-ocr-latest / qwen3-vl-4b")
    ap.add_argument("--pages", help="page range, e.g. '1,3-5,8' (PDF only)")
    # lmstudio-specific
    ap.add_argument("--host", default=os.environ.get("QWEN_OCR_HOST",
                                                     "http://localhost:1234/v1"),
                    help="LM Studio base URL")
    ap.add_argument("--dpi", type=int, default=200,
                    help="rasterization DPI for lmstudio backend (default 200)")
    args = ap.parse_args()

    if not args.input.exists():
        console.print(f"[red]not found:[/red] {args.input}")
        return 1

    out_path = args.output or args.input.with_suffix(".md")

    if args.provider == "mistral":
        model = args.model or "mistral-ocr-latest"
        pages_list = None
        if args.pages and args.input.suffix.lower() == ".pdf":
            pdf = pdfium.PdfDocument(str(args.input))
            pages_list = parse_pages(args.pages, len(pdf))
            pdf.close()
        text = mistral_ocr(args.input, model, pages_list)
    else:
        model = args.model or os.environ.get("QWEN_OCR_MODEL", "qwen3-vl-4b")
        text = lmstudio_ocr(args.input, model, args.host, args.dpi, args.pages)

    out_path.write_text(text, encoding="utf-8")
    console.print(f"[green]✓[/green] {out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
