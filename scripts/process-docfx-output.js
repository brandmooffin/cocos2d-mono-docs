const fs = require("fs");
const path = require("path");
const yaml = require("js-yaml");

function processDocFxFiles() {
  console.log("Starting DocFX YAML to MDX conversion...");

  const apiDocsDir = path.join(__dirname, "../docs/api");

  // Check if the directory exists
  if (!fs.existsSync(apiDocsDir)) {
    console.log("No API docs directory found. Skipping processing.");
    return;
  }

  const files = fs
    .readdirSync(apiDocsDir)
    .filter((file) => file.endsWith(".yml"));
  console.log(`Found ${files.length} YAML files to process`);

  let processedCount = 0;
  let skippedCount = 0;

  files.forEach((file) => {
    if (file === "toc.yml" || file === ".manifest") {
      console.log(`Skipping system file: ${file}`);
      skippedCount++;
      return;
    }

    try {
      processYamlFile(apiDocsDir, file);
      processedCount++;
    } catch (error) {
      console.error(`Failed to process ${file}:`, error.message);
      skippedCount++;
    }
  });

  console.log(`\nConversion complete!`);
  console.log(`✅ Processed: ${processedCount} files`);
  console.log(`⚠️  Skipped: ${skippedCount} files`);
}

function processYamlFile(sourceDir, filename) {
  const sourcePath = path.join(sourceDir, filename);
  const targetFilename = filename.replace(".yml", ".md");
  const targetPath = path.join(sourceDir, targetFilename);

  const yamlContent = fs.readFileSync(sourcePath, "utf8");
  const data = yaml.load(yamlContent);

  if (!data || !data.items || data.items.length === 0) {
    console.log(`Skipping ${filename} - no items found`);
    return;
  }

  const mdxContent = convertYamlToMdx(data, targetFilename);

  // Validate the generated content
  const issues = validateMdxContent(mdxContent, targetFilename);
  if (issues.length > 0) {
    console.warn(`⚠️  Validation warnings for ${targetFilename}:`);
    issues.forEach((issue) => console.warn(`  - ${issue}`));
  }

  fs.writeFileSync(targetPath, mdxContent);
  console.log(`✅ Converted: ${filename} -> ${targetFilename}`);

  // Remove the original YAML file
  fs.unlinkSync(sourcePath);
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
  } else if (item.type === "Enum") {
    content += generateEnumComponent(item, data);
  } else if (item.type === "Struct") {
    content += generateStructComponent(item, data);
  } else {
    // Fallback for other types
    content += generateGenericContent(item);
  }

  return content;
}

function buildAttribute(name, value) {
  const sanitized = sanitizeForJsx(value);
  return sanitized ? ` ${name}="${sanitized}"` : "";
}

function generateClassComponent(classItem, data) {
  const name = sanitizeForJsx(classItem.name);
  const namespace = sanitizeForJsx(classItem.namespace || "");
  const nameAttr = name ? ` name="${name}"` : "";
  const namespaceAttr = namespace ? ` namespace="${namespace}"` : "";
  const descriptionAttr = buildAttribute("description", classItem.summary);

  let content = `<ApiClass${nameAttr}${namespaceAttr}${descriptionAttr}>\n\n`;

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

    // Add fields
    if (groupedChildren.Field && groupedChildren.Field.length > 0) {
      content += "## Fields\n\n";
      groupedChildren.Field.forEach((field) => {
        content += generatePropertyComponent(field, false);
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

    // Add events
    if (groupedChildren.Event && groupedChildren.Event.length > 0) {
      content += "## Events\n\n";
      groupedChildren.Event.forEach((event) => {
        content += generateEventComponent(event);
      });
    }

    // Add other members
    Object.keys(groupedChildren).forEach((type) => {
      if (
        !["Constructor", "Property", "Method", "Field", "Event"].includes(type)
      ) {
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

function generateStructComponent(structItem, data) {
  // Structs are rendered using the ApiClass component but labeled as "Struct" to distinguish their type
  const name = sanitizeForJsx(structItem.name);
  const namespace = sanitizeForJsx(structItem.namespace || "");
  const nameAttr = name ? ` name="${name}"` : "";
  const namespaceAttr = namespace ? ` namespace="${namespace}"` : "";
  const descriptionAttr = buildAttribute("description", structItem.summary);

  let content = `<ApiClass${nameAttr}${namespaceAttr}${descriptionAttr}>\n\n`;
  content += `**Type:** Struct\n\n`;

  // Process children similar to classes
  if (structItem.children && structItem.children.length > 0) {
    const groupedChildren = groupChildren(structItem.children, data);

    Object.keys(groupedChildren).forEach((type) => {
      content += `## ${type}s\n\n`;
      groupedChildren[type].forEach((member) => {
        if (type === "Method") {
          content += generateMethodComponent(member, false);
        } else if (type === "Property" || type === "Field") {
          content += generatePropertyComponent(member, false);
        } else {
          content += generateGenericMemberComponent(member);
        }
      });
    });
  }

  content += "\n</ApiClass>";
  return content;
}

function generateEnumComponent(enumItem, data) {
  const name = sanitizeForJsx(enumItem.name);
  const namespace = sanitizeForJsx(enumItem.namespace || "");
  const nameAttr = name ? ` name="${name}"` : "";
  const namespaceAttr = namespace ? ` namespace="${namespace}"` : "";
  const descriptionAttr = buildAttribute("description", enumItem.summary);

  let content = `<ApiClass${nameAttr}${namespaceAttr}${descriptionAttr}>\n\n`;
  content += `**Type:** Enum\n\n`;

  // Add enum values
  if (enumItem.children && enumItem.children.length > 0) {
    content += "## Values\n\n";
    const enumValues = groupChildren(enumItem.children, data);

    if (enumValues.Field) {
      enumValues.Field.forEach((field) => {
        const fieldName = sanitizeForJsx(field.name);
        const nameAttr = fieldName ? ` name="${fieldName}"` : "";
        const descriptionAttr = buildAttribute("description", field.summary);
        content += `<ApiProperty${nameAttr} type="enum value"${descriptionAttr} />\n\n`;
      });
    }
  }

  content += "\n</ApiClass>";
  return content;
}

function generateMethodComponent(methodItem, standalone = true) {
  const name = sanitizeForJsx(methodItem.name);
  const signature = generateMethodSignature(methodItem);
  const nameAttr = name ? ` name="${name}"` : "";
  const signatureAttr = signature ? ` signature="${signature}"` : "";
  const descriptionAttr = buildAttribute("description", methodItem.summary);

  let content = `<ApiMethod${nameAttr}${signatureAttr}${descriptionAttr}>\n\n`;

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
      const nameAttr = paramName ? ` name="${paramName}"` : "";
      const typeAttr = paramType ? ` type="${paramType}"` : "";
      const descriptionAttr = buildAttribute("description", param.description);
      content += `    <ApiParameter${nameAttr}${typeAttr}${descriptionAttr} />\n`;
    });
    content += "  </ApiParameters>\n\n";
  }

  // Add return information
  if (methodItem.syntax && methodItem.syntax.return) {
    const returnType = sanitizeForJsx(methodItem.syntax.return.type || "void");
    const typeAttr = returnType ? ` type="${returnType}"` : "";
    const descriptionAttr = buildAttribute(
      "description",
      methodItem.syntax.return.description
    );
    if (returnType !== "void" || methodItem.syntax.return.description) {
      content += `  <ApiReturns${typeAttr}${descriptionAttr} />\n\n`;
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
      propertyItem.type ||
      "object"
  );
  const nameAttr = name ? ` name="${name}"` : "";
  const typeAttr = type ? ` type="${type}"` : "";
  const descriptionAttr = buildAttribute("description", propertyItem.summary);

  return `<ApiProperty${nameAttr}${typeAttr}${descriptionAttr} />\n\n`;
}

function generateEventComponent(eventItem) {
  const name = sanitizeForJsx(eventItem.name);
  const type = sanitizeForJsx(eventItem.type || "event");
  const nameAttr = name ? ` name="${name}"` : "";
  const typeAttr = type ? ` type="${type}"` : "";
  const descriptionAttr = buildAttribute("description", eventItem.summary);

  return `<ApiProperty${nameAttr}${typeAttr}${descriptionAttr} />\n\n`;
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

  return (
    String(text)
      // Replace generic type parameters with safe alternatives
      .replace(/<([^>]+)>/g, "&lt;$1&gt;")
      // Handle curly braces - escape as HTML entities for MDX content
      .replace(/\{/g, "&#123;")
      .replace(/\}/g, "&#125;")
      .replace(/\r\n/g, " ")
      .replace(/\n/g, " ")
      .replace(/\s+/g, " ")
      .trim()
  );
}

function sanitizeForJsx(text) {
  if (!text) return "";

  return (
    String(text)
      // Handle ampersands first to avoid double-encoding
      .replace(/&/g, "&amp;")
      // Replace generic type parameters completely for JSX attributes
      .replace(/<[^>]+>/g, "")
      // Handle backslashes - remove them entirely from JSX attributes
      .replace(/\\/g, "")
      // Handle quotes
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;")
      // Handle curly braces - remove them from JSX attributes as they cause parsing errors
      .replace(/[{}]/g, "")
      // Clean up whitespace
      .replace(/\r\n/g, " ")
      .replace(/\n/g, " ")
      .replace(/\s+/g, " ")
      .trim()
  );
}

function sanitizeCodeBlock(code) {
  if (!code) return "";

  return String(code).replace(/\r\n/g, "\n").replace(/\t/g, "    ").trim();
}

function sanitizeId(id) {
  if (!id) return "unknown";

  return (
    String(id)
      // Remove generic type parameters completely
      .replace(/<[^>]+>/g, "")
      // Replace any non-alphanumeric characters with dashes
      .replace(/[^a-zA-Z0-9._-]/g, "-")
      // Remove leading/trailing dashes
      .replace(/^-+|-+$/g, "")
      // Collapse multiple dashes
      .replace(/-+/g, "-")
      .toLowerCase()
  );
}

function validateMdxContent(content, filename) {
  const issues = [];

  // Check for common MDX issues
  if (content.includes("<T>")) {
    issues.push("Contains unescaped generic type parameter <T>");
  }

  // Check for unescaped backslashes in JSX attributes
  const jsxAttributePattern = /(\w+)="([^"]*\\[^"]*)/g;
  let match;
  while ((match = jsxAttributePattern.exec(content)) !== null) {
    issues.push(`Unescaped backslash in ${match[1]} attribute`);
  }

  return issues;
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
