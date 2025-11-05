#!/usr/bin/env python3

import os
import re
import yaml
from typing import List, Dict, Optional

def get_meta_data(post_path: str) -> Optional[Dict]:
    """
    Extract metadata from the front matter of a Markdown post file.

    Args:
        post_path: Path to the Markdown file

    Returns:
        Dictionary containing the parsed YAML front matter, or None if error
    """
    try:
        # Read the entire post file
        with open(post_path, "r", encoding="utf-8") as f:
            post_file = f.read()

        # Use regex to find content between --- delimiters (front matter)
        meta_match = re.search(r"^---\s*\n(.*?)\n---\s*\n",
                               post_file,
                               re.DOTALL)

        if not meta_match:
            print(f"WARN: meta not found in {post_path}")
            return None

        # Parse YAML content from the front matter
        meta_data = yaml.safe_load(meta_match.group(1))

        return meta_data

    except Exception as e:
        print(f"ERRO: {e}")
        return None

def get_post_list(post_dir: str) -> List[Dict]:
    """
    Scan a directory for Markdown posts and extract their metadata.

    Args:
        post_dir: Directory path containing Markdown post files

    Returns:
        List of dictionaries containing post metadata, sorted by date (newest first)
    """
    post_list = []

    # Check if the posts directory exists
    if not os.path.exists(post_dir):
        print(f"ERRO: {post_dir} does not exist")
        return post_list

    # Iterate through all files in the post directory
    for post_name in os.listdir(post_dir):
        # Only process Markdown files
        if not post_name.endswith(".md"):
            continue

        post_path = os.path.join(post_dir, post_name)

        # Extract metadata from the post file
        meta_data = get_meta_data(post_path)

        if not meta_data:
            continue

        # Get required fields from metadata
        date = meta_data.get("date")
        desc = meta_data.get("desc")

        # Validate that required fields exist
        if not date:
            print(f"WARN: {post_name} is missing the date field")
            continue

        if not desc:
            print(f"WARN: {post_name} is missing the desc field")
            continue

        # Add valid post to the list
        post_list.append({
            "name": post_name.replace(".md", "/"),  # Convert .md to directory path
            "date": str(date),  # Ensure date is string
            "desc": desc
        })

        print(f"Find: {post_dir}/{post_name}")

    # Sort posts by date in descending order (newest first)
    post_list.sort(key=lambda x: x["date"], reverse=True)

    return post_list

def generate_news_html(post_list: List[Dict], html_file: str) -> None:
    """
    Generate HTML content from post list and write to file.

    Args:
        post_list: List of post dictionaries containing metadata
        html_file: Output HTML file path
    """
    html_divs = ""

    # Display maximum 3 posts (or all if less than 3)
    post_list_temp = post_list[:3] if len(post_list) > 3 else post_list

    # Generate HTML div for each post
    for post in post_list_temp:
        html_divs += f'''
<div class="my-4">
    <a href="/news/{post['name']}" style="color: var(--md-typeset-color);">
        <div class="font-bold">{post['date']}</div>
        <div>{post['desc']}</div>
    </a>
</div>
'''

    # Add "More" link if there are more than 3 posts
    if len(post_list) > 3:
        # Use Chinese for Chinese pages, English for others
        more = "查看更多" if "zh" in html_file else "More"
        html_divs += f'''
<div class="my-4 text-right">
    <a href="/news/">{more}</a>
</div>
'''

    # Ensure output directory exists
    os.makedirs(os.path.dirname(html_file), exist_ok=True)

    # Write generated HTML to file
    with open(html_file, "w", encoding="utf-8") as f:
        f.write(html_divs)

    print(f"Done: {html_file}")

if __name__ == "__main__":
    # Generate news HTML for Chinese and English versions
    generate_news_html(get_post_list("src/zh/news/posts"), "src/zh/news.html")
    generate_news_html(get_post_list("src/en/news/posts"), "src/en/news.html")
