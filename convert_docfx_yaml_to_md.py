import os
import re
import yaml
import hashlib

INPUT_DIR = os.path.join("cocos2d-mono", "docfx", "api")
OUTPUT_DIR = os.path.join("docs", "api")

os.makedirs(OUTPUT_DIR, exist_ok=True)

# YAML loader that ignores unknown tags (like !!value)
class IgnoreUnknownTagsLoader(yaml.SafeLoader):
    def construct_undefined(self, node):
        return self.construct_scalar(node)

IgnoreUnknownTagsLoader.add_constructor(None, IgnoreUnknownTagsLoader.construct_undefined)

def sanitize_filename(uid):
    # Remove illegal filename characters (Windows-safe)
    safe = re.sub(r'[<>:"/\\|?*@()#`,\[\]{}]', '', uid)

    # Truncate and append a hash if it's too long
    if len(safe) > 100:
        hash_suffix = hashlib.md5(uid.encode('utf-8')).hexdigest()[:8]
        safe = safe[:80] + '-' + hash_suffix

    return safe

def sanitize_id(uid):
    safe = re.sub(r'[\/:<>\"|?*@()#`,\[\]{}]', '.', uid)  # Strip problem characters
    if len(safe) > 100:
        hash_suffix = hashlib.md5(uid.encode('utf-8')).hexdigest()[:8]
        safe = safe[:80] + '-' + hash_suffix
    return safe

def escape_yaml_string(value):
    """Escape and quote YAML-safe string"""
    escaped = str(value).replace('"', '\\"')
    return f'"{escaped}"'

for filename in os.listdir(INPUT_DIR):
    if not filename.endswith(".yml"):
        continue

    filepath = os.path.join(INPUT_DIR, filename)
    with open(filepath, 'r', encoding='utf-8') as file:
        try:
            data = yaml.load(file, Loader=IgnoreUnknownTagsLoader)
        except yaml.YAMLError as e:
            print(f"Skipping {filename} due to YAML error: {e}")
            continue

    if not data or 'items' not in data:
        continue

    for item in data['items']:
        uid = str(item.get('uid') or 'unknown')
        raw_name = item.get('name')
        name = str(raw_name) if isinstance(raw_name, str) and raw_name.strip() else uid
        type_ = item.get('type', '')
        summary = item.get('summary', '')
        syntax = item.get('syntax', {}).get('content', '')
        parameters = item.get('syntax', {}).get('parameters', [])
        returns = item.get('returns', '')
        inheritance = item.get('inheritance', [])

        sanitized_id = sanitize_id(uid)

        if ':' in sanitized_id:
            print(f" UNSAFE ID: {uid} > {sanitized_id}")

        print(f" Writing: {uid} > {sanitized_id}")
				
        # Build Markdown content
        md = f"""---
id: {sanitized_id}
title: {escape_yaml_string(name)}
---

# {name}

**Type**: {type_}

"""

        if inheritance:
            md += "## Inheritance\n"
            md += " → ".join(inheritance) + "\n\n"

        if summary:
            md += f"## Summary\n{summary}\n\n"

        if syntax:
            md += f"## Syntax\n```csharp\n{syntax}\n```\n\n"

        if parameters:
            md += "## Parameters\n\n"
            for param in parameters:
                pname = param.get('id', '')
                ptype = param.get('type', '')
                pdesc = param.get('description', '')
                md += f"- **{pname}** ({ptype}): {pdesc}\n"
            md += "\n"

        if returns:
            md += f"## Returns\n\n{returns}\n"

        output_filename = sanitize_filename(uid) + ".md"
        output_path = os.path.join(OUTPUT_DIR, output_filename)

        try:
            with open(output_path, 'w', encoding='utf-8') as mdfile:
                mdfile.write(md)
        except OSError as e:
            print(f"Failed to write {output_filename}: {e}")

print("YAML successfully converted to Docusaurus-compatible Markdown.")