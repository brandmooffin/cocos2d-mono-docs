import os
import yaml
import hashlib
import re

INPUT_DIR = os.path.join("cocos2d-mono", "docfx", "api")
OUTPUT_DIR = os.path.join("docs", "api")

os.makedirs(OUTPUT_DIR, exist_ok=True)

# YAML loader that ignores unknown tags (e.g. !!value)
class IgnoreUnknownTagsLoader(yaml.SafeLoader):
    def construct_undefined(self, node):
        return self.construct_scalar(node)

IgnoreUnknownTagsLoader.add_constructor(None, IgnoreUnknownTagsLoader.construct_undefined)

def escape_yaml_string(value):
    # Quote the string and escape internal quotes
    escaped = str(value).replace('"', '\\"')
    return f'"{escaped}"'

def sanitize_filename(uid):
    # Remove illegal filename characters (Windows-safe)
    safe = re.sub(r'[<>:"/\\|?*@(),]', '', uid)

    # Truncate long filenames and add hash to ensure uniqueness
    if len(safe) > 100:
        hash_suffix = hashlib.md5(uid.encode('utf-8')).hexdigest()[:8]
        safe = safe[:80] + '-' + hash_suffix

    return safe

for filename in os.listdir(INPUT_DIR):
    if not filename.endswith(".yml"):
        continue

    filepath = os.path.join(INPUT_DIR, filename)
    with open(filepath, 'r', encoding='utf-8') as file:
        try:
            data = yaml.load(file, Loader=IgnoreUnknownTagsLoader)
        except yaml.YAMLError as e:
            print(f"⚠️ Skipping {filename} due to YAML error: {e}")
            continue

    if not data or 'items' not in data:
        continue

    for item in data['items']:
        uid = item.get('uid') or 'unknown'

# Force name to string; fall back if None or not a string
raw_name = item.get('name')
name = str(raw_name) if isinstance(raw_name, str) and raw_name.strip() else uid
        type_ = item.get('type', '')
        summary = item.get('summary', '')
        syntax = item.get('syntax', {}).get('content', '')
        parameters = item.get('syntax', {}).get('parameters', [])
        returns = item.get('returns', '')
        inheritance = item.get('inheritance', [])

        # Build Markdown content
        md = f"""---
id: {uid}
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

        output_file = os.path.join(OUTPUT_DIR, f"{sanitize_filename(uid)}.md")
        with open(output_file, 'w', encoding='utf-8') as mdfile:
            mdfile.write(md)

print("YAML successfully converted to Docusaurus-compatible Markdown.")