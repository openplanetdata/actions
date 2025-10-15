#!/usr/bin/env python3
import os
import sys
import json

def normalize_tags():
    tags_input = os.environ.get('TAGS', '')

    if not tags_input or tags_input.strip() == '':
        print('[]')
        return 0

    # Split by both newlines and commas, then clean up
    tags = []
    for line in tags_input.split('\n'):
        for tag in line.split(','):
            tag = tag.strip()
            if tag:
                tags.append(tag)

    # Remove duplicates while preserving order
    seen = set()
    unique_tags = []
    for tag in tags:
        if tag not in seen:
            seen.add(tag)
            unique_tags.append(tag)

    print(json.dumps(unique_tags))
    return 0

if __name__ == '__main__':
    try:
        sys.exit(normalize_tags())
    except Exception as e:
        print(f"Error normalizing tags: {e}", file=sys.stderr)
        sys.exit(1)
