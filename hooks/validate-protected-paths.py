import json
import sys
import os

data = json.load(sys.stdin)
tool_input = data.get("tool_input", {})
path = tool_input.get("file_path", "")

if not path:
    sys.exit(0)

# Normaliza separadores
path = path.replace("\\", "/")

PROTECTED = [
    "/.claude/docs/",
    "/.claude/agents/",
    "/.claude/commands/",
    "/.claude/instructions/",
]
PROTECTED_FILES = ["CLAUDE.md"]

blocked = any(p in path for p in PROTECTED)
if not blocked:
    blocked = any(path.endswith(f) or f"/{f}" in path for f in PROTECTED_FILES)

if blocked:
    print(f"AVISO: '{os.path.basename(path)}' está em local protegido.")
    print("Só altere locais protegidos quando o usuário pedir explicitamente na mesma mensagem, citando o caminho.")

sys.exit(0)
