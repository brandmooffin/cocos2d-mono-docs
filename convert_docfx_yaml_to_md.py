import os
import yaml

INPUT_DIR = "docfx/api"
OUTPUT_DIR = "docs/api"

os.makedirs(OUTPUT_DIR, exist_ok=True)

def sanitize_filename(uid):
    return uid.replace('<', '').replace('>', '').replace(':', '').replace('*', '').replace('?', '').replace('/', '_')

for filename in os.listdir(INPUT_DIR):
    if not filename.endswith(".yml"):
        continue

    with open(os.path.join(INPUT_DIR, filename), 'r', encoding='utf-8') as file:
        data = yaml.safe_load(file)

    if not data or 'items' not in data:
        continue

    for item in data['items']:
        uid = item.get('uid', 'unknown')
        name = item.get('name', uid)
        type_ = item.get('type', '')
        summary = item.get('summary', '')
        syntax = item.get('syntax', {}).get('content', '')
        parameters = item.get('syntax', {}).get('parameters', [])
        returns = item.get('returns', '')
        inheritance = item.get('inheritance', [])

        # Markdown content
        md = f"""---
id: {uid}
title: {name}
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

        # Output file
        out_file = os.path.join(OUTPUT_DIR, f"{sanitize_filename(uid)}.md")
        with open(out_file, 'w', encoding='utf-8') as mdfile:
            mdfile.write(md)

print("✅ YAML converted to Docusaurus-compatible Markdown.")