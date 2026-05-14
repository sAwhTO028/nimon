#!/usr/bin/env python3
"""Emit JSON lines for app_en.arb from validation_fallback_messages.dart map."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "lib/core/validation/validation_fallback_messages.dart"
lines = SRC.read_text(encoding="utf-8").splitlines()

entries = []
i = 0
while i < len(lines):
    line = lines[i]
    m = re.match(r"\s+'([^']+)'\s*:\s*", line)
    if not m:
        i += 1
        continue
    key = m.group(1)
    rest = line[m.end() :]
    if "'" in rest and rest.strip().startswith("'"):
        vm = re.match(r"'((?:[^'\\]|\\.)*)'", rest.strip())
        if vm:
            val = vm.group(1).encode().decode("unicode_escape")
            entries.append((key, val))
            i += 1
            continue
    i += 1
    val_parts = []
    while i < len(lines):
        ln = lines[i]
        vm = re.search(r"'((?:[^'\\]|\\.)*)'", ln)
        if vm:
            val_parts.append(vm.group(1))
        if ");" in ln or (ln.strip().endswith(",") and "'" in ln and val_parts):
            break
        i += 1
    val = "".join(val_parts).encode().decode("unicode_escape") if val_parts else ""
    entries.append((key, val))


def mk_arb_key(message_key: str) -> str:
    parts = message_key.split(".")
    return "validation" + "".join(p[:1].upper() + p[1:] if p else "" for p in parts)


def arb_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def placeholders(template: str):
    return sorted(set(re.findall(r"\{(\w+)\}", template)))

out_lines = []
for k, v in entries:
    ak = mk_arb_key(k)
    out_lines.append(f'  "{ak}": "{arb_escape(v)}"')
    ph = placeholders(v)
    if ph:
        out_lines.append(f'  "@{ak}": {{')
        out_lines.append('    "description": "validation message",')
        out_lines.append('    "placeholders": {')
        for p in ph:
            out_lines.append(f'      "{p}": {{ "type": "Object" }}')
        out_lines.append("    }")
        out_lines.append("  }")

out_path = ROOT / "tool" / "_validation_arb_fragment.txt"
out_path.write_text(",\n".join(out_lines), encoding="utf-8")
print(f"Parsed {len(entries)} entries -> {out_path}")
