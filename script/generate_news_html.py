#!/usr/bin/env python3

"""generate_news_html.py

Scan a directory of Markdown posts, extract front-matter metadata, and
generate a small HTML snippet listing the newest posts. The script writes
language-specific snippets (e.g. `src/zh/news.html`) used by templates.

Usage: run as a script; it currently generates Chinese and English outputs.
"""

import os
import re
import yaml
from typing import List, Dict, Optional


def get_environment() -> str:
    """Return the current environment name from the MKDOCS_ENV env var.

    Defaults to "serve" when the variable is not set. Callers use this to
    adjust generated link paths for deployment vs local preview.
    """
    return os.environ.get("MKDOCS_ENV", "serve")


def get_meta_data(post_path: str) -> Optional[Dict]:
    """Extract YAML front-matter metadata from a Markdown file.

    The function looks for the first block delimited by `---` and parses it
    as YAML. If the front matter is missing or cannot be parsed, None is
    returned and a warning is printed.

    Args:
        post_path: Full path to the Markdown file.

    Returns:
        A dict with parsed metadata (usually containing `date` and `desc`),
        or None on failure.
    """
    try:
        with open(post_path, "r", encoding="utf-8") as f:
            post_file = f.read()

        # Capture content between the first pair of --- markers
        meta_match = re.search(r"^---\s*\n(.*?)\n---\s*\n",
                               post_file,
                               re.DOTALL)

        if not meta_match:
            print(f"[gen] [warn] meta not found in {post_path}")
            return None

        meta_data = yaml.safe_load(meta_match.group(1))
        return meta_data

    except Exception as e:
        print(f"[gen] [fail] {e}")
        return None


def get_post_list(post_dir: str) -> List[Dict]:
    """Scan `post_dir` for Markdown posts and collect validated metadata.

    Each valid post contributes a dict with keys: `name` (path fragment),
    `date` (string), and `desc` (summary). Only posts that include both
    `date` and `desc` in their front-matter are included.

    Args:
        post_dir: Directory where post files are stored.

    Returns:
        A list of post metadata dicts sorted by date (newest first).
    """
    post_list: List[Dict] = []

    if not os.path.exists(post_dir):
        print(f"[gen] [fail] {post_dir} does not exist")
        return post_list

    for post_name in os.listdir(post_dir):
        if not post_name.endswith(".md"):
            continue

        post_path = os.path.join(post_dir, post_name)
        meta_data = get_meta_data(post_path)

        if not meta_data:
            continue

        date = meta_data.get("date")
        desc = meta_data.get("desc")

        if not date:
            print(f"[gen] [warn] {post_name} is missing the date field")
            continue

        if not desc:
            print(f"[gen] [warn] {post_name} is missing the desc field")
            continue

        post_list.append({
            # Convert filename.md to a path-like fragment used by templates
            "name": post_name.replace(".md", "/"),
            "date": str(date),
            "desc": desc,
        })

        print(f"[gen] find {post_dir}/{post_name}")

    # Sort by date descending (newest first). Assumes date strings are
    # comparable; if using complex date formats, consider parsing to datetime.
    post_list.sort(key=lambda x: x["date"], reverse=True)
    return post_list


def generate_news_html(post_list: List[Dict], html_file: str, post_num: int = 3) -> None:
    """Render a small HTML fragment listing the newest posts.

    The generated HTML uses simple wrappers and links. For deployed builds
    the function may prefix links (e.g. with `/en`) depending on the
    environment and output filename.

    Args:
        post_list: List of post metadata dicts (as returned by get_post_list).
        html_file: Destination HTML file path to write the fragment.
        post_num: Number of posts to include (default 3).
    """
    news_path = ""
    html_divs = ""

    if get_environment() == "deploy":
        if "en" in html_file:
            news_path = "/en"

    # Choose posts to display
    post_list_temp = post_list[:post_num] if len(post_list) > post_num else post_list

    for post in post_list_temp:
        html_divs += f'''\n<div class="my-4">\n    <a href="{news_path}/news/{post['name']}" style="color: var(--md-typeset-color);">\n        <div class="font-bold">{post['date']}</div>\n        <div>{post['desc']}</div>\n    </a>\n</div>\n'''

    if len(post_list) > post_num:
        more = "查看更多" if "zh" in html_file else "More"
        html_divs += f'''\n<div class="my-4 text-right">\n    <a href="{news_path}/news/">{more}</a>\n</div>\n'''

    os.makedirs(os.path.dirname(html_file), exist_ok=True)
    with open(html_file, "w", encoding="utf-8") as f:
        f.write(html_divs)

    print(f"[gen] done: {html_file}")


if __name__ == "__main__":
    # Generate news HTML fragments for Chinese and English pages
    news_lang_list = ["zh", "en"]
    for news_lang in news_lang_list:
        generate_news_html(
            get_post_list("src/" + news_lang + "/news/posts"),
            "src/" + news_lang + "/news.html",
            4,
        )
