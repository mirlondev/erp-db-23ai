import os
import re

directories = [
    '/home/odema/Bureau/OracleDBA/migration_26ai/erp-db-23ai/apex/apps/app-pos/pages',
    '/home/odema/Bureau/OracleDBA/migration_26ai/erp-db-23ai/apex/apps/app-stock/pages'
]

def format_inline_blocks(content):
    # Fix aliases with hyphens and quotes
    content = re.sub(r"alias:\s*'([^']+)'", lambda m: "alias: " + m.group(1).replace("-", "_"), content)
    content = re.sub(r'alias:\s*"([^"]+)"', lambda m: "alias: " + m.group(1).replace("-", "_"), content)
    content = re.sub(r"alias:\s*([A-Za-z0-9\-]+)", lambda m: "alias: " + m.group(1).replace("-", "_"), content)
    
    # Fix heading { title: 'X' alignment: end } -> heading { heading: X \n alignment: end }
    def heading_repl(m):
        inner = m.group(1).strip()
        inner = re.sub(r"title:\s*'([^']+)'", r"heading: \1", inner)
        inner = re.sub(r'title:\s*"([^"]+)"', r"heading: \1", inner)
        # split by spaces if there are other props like alignment: end
        props = re.split(r'\s+(?=[a-zA-Z]+:)', inner)
        return "heading {\n" + "".join([f"        {p}\n" for p in props]) + "    }"
    content = re.sub(r"heading\s*\{\s*([^}]+)\s*\}", heading_repl, content)

    # Fix label { title: 'X' } -> label { label: X }
    def label_repl(m):
        inner = m.group(1).strip()
        inner = re.sub(r"title:\s*'([^']+)'", r"label: \1", inner)
        inner = re.sub(r'title:\s*"([^"]+)"', r"label: \1", inner)
        props = re.split(r'\s+(?=[a-zA-Z]+:)', inner)
        return "label {\n" + "".join([f"        {p}\n" for p in props]) + "    }"
    content = re.sub(r"label\s*\{\s*([^}]+)\s*\}", label_repl, content)

    # General block formatter for other single-line blocks: layout { ... } , source { ... }, etc.
    # We only want to target blocks that are on a single line
    def block_repl(m):
        name = m.group(1)
        inner = m.group(2).strip()
        if '\n' in inner: return m.group(0) # already multiline
        props = re.split(r'\s+(?=[a-zA-Z]+:)', inner)
        return name + " {\n" + "".join([f"        {p}\n" for p in props]) + "    }"
    
    # Target layout, source, appearance, settings, default, validation, execution, error
    for tag in ['layout', 'source', 'appearance', 'settings', 'default', 'validation', 'execution', 'error', 'lov']:
        content = re.sub(r"\b(" + tag + r")\s*\{\s*([^}]+)\s*\}", block_repl, content)

    # Fix specific token issues
    # error { errorMessage: '#SQLERRM_TEXT#' } -> quotes around #SQLERRM_TEXT# might be bad? Let's just remove quotes.
    content = content.replace("errorMessage: '#SQLERRM_TEXT#'", "errorMessage: #SQLERRM_TEXT#")
    
    # Button names with dashes might cause issues, e.g. @add-line
    content = re.sub(r"@([a-zA-Z0-9]+)-([a-zA-Z0-9\-]+)", lambda m: "@" + m.group(1) + "_" + m.group(2).replace("-", "_"), content)
    # Also fix the button definitions: button add-line -> button add_line
    content = re.sub(r"button ([a-zA-Z0-9]+)-([a-zA-Z0-9\-]+) \(", lambda m: "button " + m.group(1) + "_" + m.group(2).replace("-", "_") + " (", content)
    
    return content

for d in directories:
    for f in os.listdir(d):
        if f.endswith('.apx'):
            path = os.path.join(d, f)
            with open(path, 'r', encoding='utf-8') as file:
                content = file.read()
            
            new_content = format_inline_blocks(content)
            
            if new_content != content:
                with open(path, 'w', encoding='utf-8') as file:
                    file.write(new_content)
                print(f"Fixed {path}")

print("Done fixing syntax.")
