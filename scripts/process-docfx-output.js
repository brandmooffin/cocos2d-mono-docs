const fs = require("fs");
const path = require("path");
const yaml = require("js-yaml");

function processDocFxFiles() {
  const apiDocsDir = path.join(__dirname, "../docs/api");

  if (!fs.existsSync(apiDocsDir)) {
    fs.mkdirSync(apiDocsDir, { recursive: true });
  }

  // Process YAML files from DocFX output
  const docfxApiDir = path.join(__dirname, "../cocos2d-mono/docfx/api");

  if (fs.existsSync(docfxApiDir)) {
    processYamlFiles(docfxApiDir, apiDocsDir);
  }
}

function processYamlFiles(sourceDir, targetDir) {
  const files = fs.readdirSync(sourceDir);

  files.forEach((file) => {
    if (file.endsWith(".yml") && file !== "toc.yml") {
      const yamlPath = path.join(sourceDir, file);
      const yamlContent = fs.readFileSync(yamlPath, "utf8");

      try {
        const data = yaml.load(yamlContent);
        const mdxContent = convertYamlToMdx(data);

        const mdFileName = file.replace(".yml", ".md");
        const mdPath = path.join(targetDir, mdFileName);

        fs.writeFileSync(mdPath, mdxContent);
        console.log(`Converted: ${file} -> ${mdFileName}`);
      } catch (error) {
        console.error(`Error processing ${file}:`, error);
      }
    }
  });
}

function convertYamlToMdx(data) {
  if (!data || !data.items || data.items.length === 0) {
    return "# No content available\n";
  }

  const item = data.items[0]; // Primary item
  let mdxContent = "";

  // Add frontmatter
  mdxContent += "---\n";
  mdxContent += `id: "${item.uid || item.name}"\n`;
  mdxContent += `title: "${item.name || "API Documentation"}"\n`;
  mdxContent += `sidebar_label: "${item.name || "API"}"\n`;
  mdxContent += "hide_table_of_contents: false\n";
  mdxContent += "---\n\n";

  // Import components
  mdxContent +=
    'import { ApiClass, ApiMethod, ApiProperty, ApiParameters, ApiParameter, ApiReturns, ApiExample } from "@site/src/components/ApiComponents";\n\n';

  // Generate content based on item type
  if (item.type === "Class") {
    mdxContent += generateClassMdx(item);
  } else if (item.type === "Method") {
    mdxContent += generateMethodMdx(item);
  } else if (item.type === "Property") {
    mdxContent += generatePropertyMdx(item);
  } else if (item.type === "Namespace") {
    mdxContent += generateNamespaceMdx(item, data);
  }

  return mdxContent;
}

function generateClassMdx(classItem) {
  let content = `<ApiClass name="${classItem.name}" namespace="${
    classItem.namespace
  }" description="${escapeDescription(classItem.summary)}">\n\n`;

  // Add inheritance info
  if (classItem.inheritance && classItem.inheritance.length > 0) {
    content += `**Inheritance:** ${classItem.inheritance.join(" → ")}\n\n`;
  }

  // Add constructors
  if (classItem.children) {
    const constructors = classItem.children.filter(
      (child) => child.type === "Constructor"
    );
    if (constructors.length > 0) {
      content += "## Constructors\n\n";
      constructors.forEach((constructor) => {
        content += generateMethodMdx(constructor, false);
      });
    }

    // Add properties
    const properties = classItem.children.filter(
      (child) => child.type === "Property"
    );
    if (properties.length > 0) {
      content += "## Properties\n\n";
      properties.forEach((property) => {
        content += generatePropertyMdx(property, false);
      });
    }

    // Add methods
    const methods = classItem.children.filter(
      (child) => child.type === "Method"
    );
    if (methods.length > 0) {
      content += "## Methods\n\n";
      methods.forEach((method) => {
        content += generateMethodMdx(method, false);
      });
    }
  }

  content += "\n</ApiClass>";
  return content;
}

function generateMethodMdx(methodItem, standalone = true) {
  const signature = generateMethodSignature(methodItem);
  const description = escapeDescription(methodItem.summary);

  let content = `<ApiMethod name="${methodItem.name}" signature="${signature}" description="${description}">\n\n`;

  // Add parameters
  if (
    methodItem.syntax &&
    methodItem.syntax.parameters &&
    methodItem.syntax.parameters.length > 0
  ) {
    content += "  <ApiParameters>\n";
    methodItem.syntax.parameters.forEach((param) => {
      const paramDescription = escapeDescription(param.description);
      content += `    <ApiParameter name="${param.id}" type="${param.type}" description="${paramDescription}" />\n`;
    });
    content += "  </ApiParameters>\n\n";
  }

  // Add return info
  if (methodItem.syntax && methodItem.syntax.return) {
    const returnDescription = escapeDescription(
      methodItem.syntax.return.description
    );
    content += `  <ApiReturns type="${methodItem.syntax.return.type}" description="${returnDescription}" />\n\n`;
  }

  // Add example if available
  if (methodItem.example) {
    content += "  <ApiExample>\n";
    content += "  ```csharp\n";
    content += `  ${methodItem.example}\n`;
    content += "  ```\n";
    content += "  </ApiExample>\n\n";
  }

  content += "</ApiMethod>\n\n";
  return content;
}

function generatePropertyMdx(propertyItem, standalone = true) {
  const description = escapeDescription(propertyItem.summary);
  const type = propertyItem.syntax ? propertyItem.syntax.return.type : "object";

  return `<ApiProperty name="${propertyItem.name}" type="${type}" description="${description}" />\n\n`;
}

function generateNamespaceMdx(namespaceItem, data) {
  let content = `# ${namespaceItem.name}\n\n`;
  content += `${escapeDescription(namespaceItem.summary)}\n\n`;

  // List classes in this namespace
  if (data.items && data.items.length > 1) {
    content += "## Classes\n\n";
    data.items.slice(1).forEach((item) => {
      if (item.type === "Class") {
        content += `- [${item.name}](./${item.uid}.md) - ${escapeDescription(
          item.summary
        )}\n`;
      }
    });
  }

  return content;
}

function generateMethodSignature(methodItem) {
  if (!methodItem.syntax) return methodItem.name;

  let signature = "";

  // Add modifiers
  if (methodItem.modifiers) {
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
  if (methodItem.syntax.parameters) {
    const paramStrings = methodItem.syntax.parameters.map(
      (param) => `${param.type} ${param.id}`
    );
    signature += paramStrings.join(", ");
  }
  signature += ")";

  return signature.replace(/"/g, '\\"'); // Escape quotes for JSX
}

function escapeDescription(description) {
  if (!description) return "";
  return description
    .replace(/"/g, '\\"')
    .replace(/\n/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

// Run the processing
processDocFxFiles();
