import os
import re
import sys

STRING_PATTERNS = [
    re.compile(r'"""(?:.|\n)*?"""'),
    re.compile(r'"(?:\\.|[^"\\\n])*"'),
    re.compile(r"'(?:\\.|[^'\\\n])*'"),
]

CODE_EXT = {".kt", ".kts", ".dart", ".gradle"}
XML_EXT = {".xml"}
YAML_EXT = {".yml", ".yaml"}


def strip_strings(text: str) -> str:
    for pattern in STRING_PATTERNS:
        text = pattern.sub('""', text)
    return text


def check(path: str) -> list:
    ext = os.path.splitext(path)[1]
    if ext not in CODE_EXT and ext not in XML_EXT and ext not in YAML_EXT:
        return []
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    problems = []
    if ext in CODE_EXT:
        cleaned = strip_strings(text)
        if re.search(r"//|/\*", cleaned):
            problems.append("line or block comment")
    elif ext in XML_EXT:
        if "<!--" in text:
            problems.append("xml comment")
    elif ext in YAML_EXT:
        for line in text.splitlines():
            if line.lstrip().startswith("#"):
                problems.append("yaml comment")
                break
    return problems


def main() -> int:
    roots = sys.argv[1:] or ["."]
    skip = {".git", ".dart_tool", "build", "node_modules", ".gradle"}
    failed = False
    for root in roots:
        for base, dirs, files in os.walk(root):
            dirs[:] = [d for d in dirs if d not in skip]
            for name in files:
                full = os.path.join(base, name)
                problems = check(full)
                if problems:
                    failed = True
                    print(f"{full}: {', '.join(problems)}")
    if failed:
        return 1
    print("no comments found")
    return 0


if __name__ == "__main__":
    sys.exit(main())
