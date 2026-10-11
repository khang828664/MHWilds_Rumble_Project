"""Stream-extract types whose name matches a regex from REFramework's il2cpp_dump.json (2 GB, no full load).

Usage: python -I tools/extract_dump_types.py <il2cpp_dump.json> <regex> <out.json>
Example: python -I tools/extract_dump_types.py il2cpp_dump.json "sound|wwise|snd_|audio" sound_types.json
"""
import json
import re
import sys

TOP_LEVEL_TYPE = re.compile(r'^    "(.*)": \{\s*$')


def extract(dump_path, name_pattern):
    pattern = re.compile(name_pattern, re.I)
    types = {}
    current_name = None
    lines = []

    def flush():
        if current_name is not None:
            types[current_name] = json.loads("{" + "".join(lines).rstrip().rstrip(",") + "}")["type"]

    with open(dump_path, encoding="utf-8", errors="replace") as dump:
        for line in dump:
            match = TOP_LEVEL_TYPE.match(line)
            if not match:
                if current_name is not None:
                    lines.append(line)
                continue
            flush()
            name = match.group(1)
            if pattern.search(name) and "<" not in name and "[" not in name:
                current_name, lines = name, ['"type": {\n']
            else:
                current_name, lines = None, []
    flush()
    return types


def main():
    dump_path, name_pattern, out_path = sys.argv[1:4]
    types = extract(dump_path, name_pattern)
    with open(out_path, "w", encoding="utf-8") as out:
        json.dump(types, out, indent=1)
    print(f"{len(types)} types -> {out_path}")


if __name__ == "__main__":
    main()
