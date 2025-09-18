const fs = require("fs");
const path = require("path");
const yaml = require("js-yaml");

function processDocFxFiles() {
  console.log("Starting DocFX processing...");

  const apiDocsDir = path.join(__dirname, "../docs/api");
  const docfxApiDir = path.join(__dirname, "../cocos2d-mono/docfx/api");

  // Create docs/api directory if it doesn't exist
  if (!fs.existsSync(apiDocsDir)) {
    fs.mkdirSync(apiDocsDir, { recursive: true });
    console.log("Created docs/api directory");
  }

  // Check if DocFX generated any files
  if (!fs.existsSync(docfxApiDir)) {
    console.log("No DocFX API directory found. Skipping processing.");
    return;
  }

  const files = fs.readdirSync(docfxApiDir);
  console.log(`Found ${files.length} files in DocFX output`);

  // Process YAML files and convert to MDX with components
  files.forEach((file) => {
    if (file.endsWith(".yml") && file !== "toc.yml") {
      processYamlFile(docfxApiDir, apiDocsDir, file);
    }
  });

  console.log("DocFX processing completed");
}

function processYamlFile(sourceDir, targetDir, filename) {
  const sourcePath = path.join(sourceDir, filename);
  const targetFilename = filename.replace(".yml", ".md");
  const targetPath = path.join(targetDir, targetFilename);

  try {
    const yamlContent = fs.readFileSync(sourcePath, "utf8");
    const data = yaml.load(yamlContent);

    if (!data || !data.items || data.items.length === 0) {
      console.log(`Skipping ${filename} - no items found`);
      return;
    }

    const mdxContent = convertYamlToMdx(data, targetFilename);
    fs.writeFileSync(targetPath, mdxContent);
    console.log(`Converted: ${filename} -> ${targetFilename}`);
  } catch (error) {
    console.error(`Error processing ${filename}:`, error.message);

    // Create a fallback minimal file
    const fallbackContent = createFallbackContent(filename);
    fs.writeFileSync(targetPath, fallbackContent);
    console.log(`Created fallback for: ${targetFilename}`);
  }
}

function convertYamlToMdx(data, filename) {
  const item = data.items[0];
  const safeTitle = sanitizeForMdx(item.name || filename.replace(".md", ""));
  const safeId = sanitizeId(
    item.uid || item.name || filename.replace(".md", "")
  );

  let content = "";

  // Add frontmatter
  content += "---\n";
  content += `id: "${safeId}"\n`;
  content += `title: "${safeTitle}"\n`;
  content += `sidebar_label: "${safeTitle}"\n`;
  content += "hide_table_of_contents: false\n";
  content += "---\n\n";

  // Import API components
  content +=
    'import { ApiClass, ApiMethod, ApiProperty, ApiParameters, ApiParameter, ApiReturns, ApiExample } from "@site/src/components/ApiComponents";\n\n';

  // Generate content based on item type
  if (item.type === "Class") {
    content += generateClassComponent(item, data);
  } else if (item.type === "Method") {
    content += generateMethodComponent(item);
  } else if (item.type === "Property") {
    content += generatePropertyComponent(item);
  } else if (item.type === "Namespace") {
    content += generateNamespaceContent(item, data);
  } else {
    // Fallback for other types
    content += generateGenericContent(item);
  }

  return content;
}

function generateClassComponent(classItem, data) {
  const name = sanitizeForJsx(classItem.name);
  const namespace = sanitizeForJsx(classItem.namespace || "");
  const description = sanitizeForJsx(classItem.summary || "");

  let content = `<ApiClass name="${name}" namespace="${namespace}" description="${description}">\n\n`;

  // Add inheritance info
  if (classItem.inheritance && classItem.inheritance.length > 0) {
    const inheritanceChain = classItem.inheritance
      .map((i) => sanitizeForMdx(i))
      .join(" → ");
    content += `**Inheritance:** ${inheritanceChain}\n\n`;
  }

  // Add implements info
  if (classItem.implements && classItem.implements.length > 0) {
    const implementsList = classItem.implements
      .map((i) => sanitizeForMdx(i))
      .join(", ");
    content += `**Implements:** ${implementsList}\n\n`;
  }

  // Process children from the class
  if (classItem.children && classItem.children.length > 0) {
    const groupedChildren = groupChildren(classItem.children, data);

    // Add constructors
    if (groupedChildren.Constructor && groupedChildren.Constructor.length > 0) {
      content += "## Constructors\n\n";
      groupedChildren.Constructor.forEach((constructor) => {
        content += generateMethodComponent(constructor, false);
      });
    }

    // Add properties
    if (groupedChildren.Property && groupedChildren.Property.length > 0) {
      content += "## Properties\n\n";
      groupedChildren.Property.forEach((property) => {
        content += generatePropertyComponent(property, false);
      });
    }

    // Add methods
    if (groupedChildren.Method && groupedChildren.Method.length > 0) {
      content += "## Methods\n\n";
      groupedChildren.Method.forEach((method) => {
        content += generateMethodComponent(method, false);
      });
    }

    // Add other members
    Object.keys(groupedChildren).forEach((type) => {
      if (!["Constructor", "Property", "Method"].includes(type)) {
        content += `## ${type}s\n\n`;
        groupedChildren[type].forEach((member) => {
          content += generateGenericMemberComponent(member);
        });
      }
    });
  }

  content += "\n</ApiClass>";
  return content;
}

function generateMethodComponent(methodItem, standalone = true) {
  const name = sanitizeForJsx(methodItem.name);
  const signature = generateMethodSignature(methodItem);
  const description = sanitizeForJsx(methodItem.summary || "");

  let content = `<ApiMethod name="${name}" signature="${signature}" description="${description}">\n\n`;

  // Add parameters
  if (
    methodItem.syntax &&
    methodItem.syntax.parameters &&
    methodItem.syntax.parameters.length > 0
  ) {
    content += "  <ApiParameters>\n";
    methodItem.syntax.parameters.forEach((param) => {
      const paramName = sanitizeForJsx(param.id || param.name);
      const paramType = sanitizeForJsx(param.type || "object");
      const paramDescription = sanitizeForJsx(param.description || "");
      content += `    <ApiParameter name="${paramName}" type="${paramType}" description="${paramDescription}" />\n`;
    });
    content += "  </ApiParameters>\n\n";
  }

  // Add return information
  if (methodItem.syntax && methodItem.syntax.return) {
    const returnType = sanitizeForJsx(methodItem.syntax.return.type || "void");
    const returnDescription = sanitizeForJsx(
      methodItem.syntax.return.description || ""
    );
    if (returnType !== "void" || returnDescription) {
      content += `  <ApiReturns type="${returnType}" description="${returnDescription}" />\n\n`;
    }
  }

  // Add example if available
  if (methodItem.example) {
    content += "  <ApiExample>\n";
    content += "  ```csharp\n";
    content += `  ${sanitizeCodeBlock(methodItem.example)}\n`;
    content += "  ```\n";
    content += "  </ApiExample>\n\n";
  }

  content += "</ApiMethod>\n\n";
  return content;
}

function generatePropertyComponent(propertyItem, standalone = true) {
  const name = sanitizeForJsx(propertyItem.name);
  const type = sanitizeForJsx(
    (propertyItem.syntax &&
      propertyItem.syntax.return &&
      propertyItem.syntax.return.type) ||
      "object"
  );
  const description = sanitizeForJsx(propertyItem.summary || "");

  return `<ApiProperty name="${name}" type="${type}" description="${description}" />\n\n`;
}

function generateGenericContent(item) {
  const name = sanitizeForMdx(item.name || "Unknown");
  const type = sanitizeForMdx(item.type || "Unknown");
  const description = sanitizeForMdx(item.summary || "");

  let content = `# ${name}\n\n`;
  content += `**Type:** ${type}\n\n`;

  if (description) {
    content += `${description}\n\n`;
  }

  return content;
}

function generateNamespaceContent(namespaceItem, data) {
  const name = sanitizeForMdx(namespaceItem.name);
  const description = sanitizeForMdx(namespaceItem.summary || "");

  let content = `# ${name}\n\n`;

  if (description) {
    content += `${description}\n\n`;
  }

  // List items in this namespace
  if (data.items && data.items.length > 1) {
    content += "## Classes and Types\n\n";
    data.items.slice(1).forEach((item) => {
      if (item.name && item.type) {
        const itemName = sanitizeForMdx(item.name);
        const itemType = sanitizeForMdx(item.type);
        const itemSummary = sanitizeForMdx(item.summary || "");
        content += `- **${itemName}** (${itemType}) - ${itemSummary}\n`;
      }
    });
  }

  return content;
}

function generateGenericMemberComponent(member) {
  const name = sanitizeForMdx(member.name || "Unknown");
  const description = sanitizeForMdx(member.summary || "");

  let content = `### ${name}\n\n`;
  if (description) {
    content += `${description}\n\n`;
  }

  return content;
}

function generateMethodSignature(methodItem) {
  if (!methodItem.syntax) return sanitizeForJsx(methodItem.name);

  let signature = "";

  // Add modifiers
  if (methodItem.modifiers && methodItem.modifiers.length > 0) {
    signature += methodItem.modifiers.join(" ") + " ";
  }

  // Add return type
  if (methodItem.syntax.return && methodItem.syntax.return.type) {
    signature += methodItem.syntax.return.type + " ";
  }

  // Add method name
  signature += methodItem.name;

  // Add parameters
  signature += "(";
  if (methodItem.syntax.parameters && methodItem.syntax.parameters.length > 0) {
    const paramStrings = methodItem.syntax.parameters.map(
      (param) =>
        `${param.type || "object"} ${param.id || param.name || "param"}`
    );
    signature += paramStrings.join(", ");
  }
  signature += ")";

  return sanitizeForJsx(signature);
}

function groupChildren(children, data) {
  const groups = {};

  children.forEach((childRef) => {
    // Find the actual child item in the data
    let childItem = null;
    if (data.references) {
      childItem = data.references.find((ref) => ref.uid === childRef);
    }

    if (!childItem && data.items) {
      childItem = data.items.find((item) => item.uid === childRef);
    }

    if (childItem) {
      const type = childItem.type || "Member";
      if (!groups[type]) {
        groups[type] = [];
      }
      groups[type].push(childItem);
    }
  });

  return groups;
}

function sanitizeForMdx(text) {
  if (!text) return "";

  return String(text)
    .replace(/\r\n/g, " ")
    .replace(/\n/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function sanitizeForJsx(text) {
  if (!text) return "";

  return String(text)
    .replace(/\\/g, "\\\\")
    .replace(/"/g, '\\"')
    .replace(/\r\n/g, " ")
    .replace(/\n/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function sanitizeCodeBlock(code) {
  if (!code) return "";

  return String(code).replace(/\r\n/g, "\n").replace(/\t/g, "    ").trim();
}

function sanitizeId(id) {
  if (!id) return "unknown";

  return String(id)
    .replace(/[^a-zA-Z0-9._-]/g, "-")
    .replace(/^-+|-+$/g, "")
    .replace(/-+/g, "-")
    .toLowerCase();
}

function createFallbackContent(filename) {
  const name = filename.replace(".yml", "").replace(/[^a-zA-Z0-9]/g, " ");

  return `---
id: "${sanitizeId(filename.replace(".yml", ""))}"
title: "${name}"
sidebar_label: "${name}"
hide_table_of_contents: false
---

# ${name}

This API documentation is currently being processed. Please check back later for complete documentation.

**Note:** This page was automatically generated from DocFX metadata.
`;
}

// Run the processing
try {
  processDocFxFiles();
} catch (error) {
  console.error("Error in DocFX processing:", error);
  process.exit(1);
}
