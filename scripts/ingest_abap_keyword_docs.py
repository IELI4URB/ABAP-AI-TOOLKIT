from __future__ import annotations

import argparse
import hashlib
import html
import json
import re
import time
import urllib.parse
import urllib.request
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path
from typing import Any

BASE = "https://help.sap.com"
PRODUCT = "abap-cloud"
DELIVERABLE = "abap-keyword"
LANGUAGE = "en-US"
ROOT_SLUGS = (
    "abap-cloud-documentation-landscape",
    "abap-dictionary-ddic",
    "abap-core-data-services-abap-cds",
    "abap-programming-language",
    "abap-rap-business-objects",
    "abap-apis",
    "abap-release-news",
    "abap-glossary",
    "abap-syntax-conventions",
)
SIGNALS = {
    "obsolete": ("obsolete",),
    "cloud_restriction": ("abap for cloud development", "abap cloud"),
    "released_api": ("released api", "release contract"),
    "security": ("security", "authorization"),
    "warning": ("warning", "caution"),
    "hint": ("hint",),
    "restriction": ("restriction", "not allowed", "cannot be used"),
    "syntax": ("syntax",),
    "rap": ("rap", "restful application programming model"),
    "cds": ("core data services", "abap cds"),
    "ddic": ("abap dictionary", "ddic"),
}


class TopicParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.text_parts: list[str] = []
        self.headings: list[str] = []
        self.links: list[str] = []
        self._heading: list[str] | None = None
        self._ignored_depth = 0

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag in {"script", "style", "svg"}:
            self._ignored_depth += 1
            return
        if self._ignored_depth:
            return
        if tag in {"h1", "h2", "h3", "h4"}:
            self._heading = []
        if tag == "a":
            href = dict(attrs).get("href")
            if href:
                self.links.append(href)

    def handle_endtag(self, tag: str) -> None:
        if tag in {"script", "style", "svg"} and self._ignored_depth:
            self._ignored_depth -= 1
            return
        if self._ignored_depth:
            return
        if tag in {"h1", "h2", "h3", "h4"} and self._heading is not None:
            heading = normalize_text(" ".join(self._heading))
            if heading:
                self.headings.append(heading)
            self._heading = None

    def handle_data(self, data: str) -> None:
        if self._ignored_depth:
            return
        value = normalize_text(data)
        if not value:
            return
        self.text_parts.append(value)
        if self._heading is not None:
            self._heading.append(value)


def normalize_text(value: str) -> str:
    return re.sub(r"\s+", " ", html.unescape(value)).strip()


def get_json(url: str, attempts: int = 5) -> dict[str, Any]:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json",
            "User-Agent": "ABAP-DEVELOPMENT-AI-TOOLKIT keyword-doc inventory/1.0",
        },
    )
    last_error: Exception | None = None
    for attempt in range(attempts):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                return json.load(response)
        except Exception as error:  # network failures are retried and reported
            last_error = error
            if attempt + 1 < attempts:
                time.sleep(min(8, 0.5 * (2**attempt)))
    raise RuntimeError(f"Failed after {attempts} attempts: {url}: {last_error}")


def metadata_url(slug: str) -> str:
    query = urllib.parse.urlencode(
        {
            "product_url": PRODUCT,
            "deliverable_url": DELIVERABLE,
            "topic_url": slug,
            "version": "LATEST",
            "language": LANGUAGE,
            "loadlandingpageontopicnotfound": "true",
        }
    )
    return f"{BASE}/http.svc/deliverableMetadata?{query}"


def page_url(deliverable_id: str, build_no: str, file_path: str, include_toc: bool) -> str:
    query = urllib.parse.urlencode(
        {
            "deliverableInfo": "1" if include_toc else "0",
            "deliverable_id": deliverable_id,
            "buildNo": build_no,
            "file_path": file_path,
            "loadlandingpageontopicnotfound": "true",
        }
    )
    return f"{BASE}/http.svc/pagecontent?{query}"


def find_node(nodes: list[dict[str, Any]], file_path: str) -> dict[str, Any] | None:
    for node in nodes:
        if node.get("u") == file_path:
            return node
        found = find_node(node.get("c") or [], file_path)
        if found:
            return found
    return None


def collect_subtree(
    node: dict[str, Any],
    root_slug: str,
    topics: dict[str, dict[str, Any]],
    path: tuple[str, ...] = (),
) -> None:
    file_path = node.get("u")
    title = normalize_text(str(node.get("t") or ""))
    current_path = path + (title,)
    if file_path:
        topic = topics.setdefault(
            file_path,
            {
                "file_path": file_path,
                "toc_title": title,
                "toc_paths": [],
                "root_sections": [],
            },
        )
        if list(current_path) not in topic["toc_paths"]:
            topic["toc_paths"].append(list(current_path))
        if root_slug not in topic["root_sections"]:
            topic["root_sections"].append(root_slug)
    for child in node.get("c") or []:
        collect_subtree(child, root_slug, topics, current_path)


def fetch_topic(
    topic: dict[str, Any],
    deliverable_id: str,
    build_no: str,
    aliases: dict[str, str],
) -> dict[str, Any]:
    file_path = topic["file_path"]
    payload = get_json(page_url(deliverable_id, build_no, file_path, False))["data"]
    body = payload.get("body") or ""
    parser = TopicParser()
    parser.feed(body)
    plain_text = normalize_text(" ".join(parser.text_parts))
    lower_text = plain_text.lower()
    loio = str((payload.get("currentPage") or {}).get("loio") or "")
    alias = aliases.get(loio)
    canonical_url = (
        f"{BASE}/docs/{PRODUCT}/{DELIVERABLE}/{alias}?locale=en-US"
        if alias
        else f"{BASE}/docs/{PRODUCT}/{DELIVERABLE}?locale=en-US"
    )
    signal_counts = {
        name: sum(lower_text.count(phrase) for phrase in phrases)
        for name, phrases in SIGNALS.items()
    }
    internal_links = sorted(
        {
            href.split("#", 1)[0]
            for href in parser.links
            if href and not re.match(r"^[a-z]+://", href) and ".html" in href
        }
    )
    return {
        **topic,
        "loio": loio,
        "title": normalize_text(str((payload.get("currentPage") or {}).get("t") or topic["toc_title"])),
        "canonical_url": canonical_url,
        "word_count": len(plain_text.split()),
        "content_sha256": hashlib.sha256(plain_text.encode("utf-8")).hexdigest(),
        "headings": parser.headings,
        "internal_link_count": len(internal_links),
        "signals": signal_counts,
    }


def write_report(
    output_dir: Path,
    inventory: dict[str, Any],
    failures: list[dict[str, str]],
) -> None:
    topics = inventory["topics"]
    root_counts = Counter()
    signal_pages: Counter[str] = Counter()
    signal_occurrences: Counter[str] = Counter()
    word_total = 0
    for topic in topics:
        word_total += topic["word_count"]
        for root in topic["root_sections"]:
            root_counts[root] += 1
        for name, count in topic["signals"].items():
            signal_occurrences[name] += count
            if count:
                signal_pages[name] += 1

    lines = [
        "# ABAP Keyword Documentation Crawl Report",
        "",
        f"Generated: `{inventory['generated_at']}`",
        f"Deliverable: `{inventory['deliverable_loio']}` / version `{inventory['version']}` / build `{inventory['build_no']}`",
        f"Requested sections: {len(inventory['root_sections'])}",
        f"Unique pages retrieved: **{len(topics)}**",
        f"Failed pages: **{len(failures)}**",
        f"Total parsed words (not stored): **{word_total:,}**",
        "",
        "The inventory stores titles, paths, headings, hashes, links, and aggregate signals only. SAP page bodies are not redistributed.",
        "",
        "## Coverage by Requested Section",
        "",
        "| Section | Pages | Official URL |",
        "|---|---:|---|",
    ]
    for root in inventory["root_sections"]:
        lines.append(
            f"| `{root['slug']}` | {root_counts[root['slug']]} | {root['url']} |"
        )
    lines.extend(
        [
            "",
            "## Signal Coverage",
            "",
            "| Signal | Pages | Occurrences |",
            "|---|---:|---:|",
        ]
    )
    for name in SIGNALS:
        lines.append(
            f"| `{name}` | {signal_pages[name]} | {signal_occurrences[name]} |"
        )
    lines.extend(
        [
            "",
            "## Validation",
            "",
            "- Every requested TOC subtree is resolved from SAP Help metadata.",
            "- Pages are deduplicated by internal file path before retrieval.",
            "- Each successful page has a SHA-256 hash of normalized plain text.",
            "- Failures retain URL and error details for retry/audit.",
        ]
    )
    if failures:
        lines.extend(["", "## Failures", ""])
        for failure in failures:
            lines.append(f"- `{failure['file_path']}`: {failure['error']}")

    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "abap-keyword-crawl-report.md").write_text(
        "\n".join(lines) + "\n", encoding="utf-8"
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Inventory supplied ABAP Keyword Documentation sections without redistributing page bodies"
    )
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--workers", type=int, default=12)
    parser.add_argument("--limit", type=int, default=0, help="Test-only page limit")
    args = parser.parse_args()

    root_metadata: dict[str, dict[str, Any]] = {}
    for slug in ROOT_SLUGS:
        root_metadata[slug] = get_json(metadata_url(slug))["data"]

    seed = root_metadata["abap-dictionary-ddic"]
    deliverable_id = str(seed["deliverable"]["id"])
    build_no = str(seed["deliverable"]["buildNo"])
    deliverable_loio = str(seed["deliverableLoio"])
    toc_payload = get_json(
        page_url(deliverable_id, build_no, str(seed["filePath"]), True)
    )["data"]
    toc = toc_payload["deliverable"]["fullToc"]

    alias_map = {
        str(item["loio"]): str(item["url"])
        for item in seed["readableUrls"]["tocReadableUrlMapping"]
    }
    topics: dict[str, dict[str, Any]] = {}
    roots: list[dict[str, Any]] = []
    for slug in ROOT_SLUGS:
        metadata = root_metadata[slug]
        file_path = str(metadata["filePath"])
        node = find_node(toc, file_path)
        if not node:
            raise RuntimeError(f"TOC node not found for {slug}: {file_path}")
        collect_subtree(node, slug, topics)
        roots.append(
            {
                "slug": slug,
                "file_path": file_path,
                "url": f"{BASE}/docs/{PRODUCT}/{DELIVERABLE}/{slug}?locale=en-US",
            }
        )

    work = [topics[key] for key in sorted(topics)]
    if args.limit:
        work = work[: args.limit]
    results: list[dict[str, Any]] = []
    failures: list[dict[str, str]] = []
    with ThreadPoolExecutor(max_workers=max(1, args.workers)) as executor:
        futures = {
            executor.submit(fetch_topic, topic, deliverable_id, build_no, alias_map): topic
            for topic in work
        }
        completed = 0
        for future in as_completed(futures):
            topic = futures[future]
            try:
                results.append(future.result())
            except Exception as error:
                failures.append(
                    {"file_path": topic["file_path"], "error": str(error)}
                )
            completed += 1
            if completed % 250 == 0 or completed == len(futures):
                print(
                    f"Processed {completed}/{len(futures)} pages; failures={len(failures)}",
                    flush=True,
                )

    results.sort(key=lambda item: item["file_path"])
    inventory = {
        "schema_version": "1.0.0",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source": "SAP Help Portal ABAP Keyword Documentation",
        "deliverable_loio": deliverable_loio,
        "version": str(seed["deliverable"]["version"]),
        "build_no": build_no,
        "language": LANGUAGE,
        "copyright_note": "Page bodies are owned by SAP and are not stored in this inventory.",
        "root_sections": roots,
        "topics": results,
        "failures": failures,
    }
    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "abap-keyword-topic-inventory.json").write_text(
        json.dumps(inventory, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    write_report(args.output_dir, inventory, failures)
    print(
        f"Inventory complete: requested={len(work)} success={len(results)} failures={len(failures)}"
    )
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
