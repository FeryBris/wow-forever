"""Convert the ForeverAPIDump SavedVariables into EmmyLua annotations.

Usage (from the game root):
    python tools/forever-api/convert.py [path/to/ForeverAPIDump.lua]

Default input: the newest WTF/Account/*/SavedVariables/ForeverAPIDump.lua
Output:        .wow-api-cache/forever/
    api.json                      raw dump as JSON (easy to grep)
    Annotations/Systems/*.lua     C_* namespaces + global API from APIDocumentation
    Annotations/ScriptObjects/*   widget API docs (signatures) from APIDocumentation
    Annotations/Enum.lua          Enum.* values from the live client
    Annotations/Event.lua         events + payloads
    Annotations/Widgets.lua       methods each widget type really has
    Annotations/Undocumented.lua  functions present in _G but not in APIDocumentation
    REPORT.md                     comparison with Ketho's vscode-wow-api annotations
"""

from __future__ import annotations

import glob
import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, ".wow-api-cache", "forever")
KETHO = os.path.join(ROOT, ".wow-api-cache", "vscode-wow-api", "Annotations")


# --------------------------------------------------------------------------
# Minimal parser for WoW SavedVariables (Lua table literals)
# --------------------------------------------------------------------------
_TOKEN = re.compile(
    r"""
    (?P<ws>\s+|--[^\n]*)
  | (?P<str>"(?:\\.|[^"\\])*")
  | (?P<num>-?(?:0[xX][0-9a-fA-F]+|(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?|inf|nan))
  | (?P<name>[A-Za-z_][A-Za-z0-9_]*)
  | (?P<op>[{}\[\]=,;])
    """,
    re.VERBOSE,
)
_ESC = {"n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "f": "\f", "v": "\v",
        "\\": "\\", '"': '"', "'": "'", "\n": "\n"}


def _unescape(s: str) -> str:
    out, i = [], 0
    while i < len(s):
        c = s[i]
        if c != "\\":
            out.append(c)
            i += 1
            continue
        n = s[i + 1]
        if n.isdigit():
            m = re.match(r"\d{1,3}", s[i + 1:])
            out.append(chr(int(m.group())))
            i += 1 + len(m.group())
        else:
            out.append(_ESC.get(n, n))
            i += 2
    # SavedVariables are raw bytes (UTF-8); \ddd escapes produce latin-1 chars
    try:
        return "".join(out).encode("latin-1").decode("utf-8")
    except (UnicodeEncodeError, UnicodeDecodeError):
        return "".join(out)


def tokenize(text: str):
    pos = 0
    for m in _TOKEN.finditer(text):
        if m.start() != pos:
            raise ValueError(f"unexpected input at {pos}: {text[pos:pos+40]!r}")
        pos = m.end()
        kind = m.lastgroup
        if kind == "ws":
            continue
        yield kind, m.group()
    if pos != len(text):
        raise ValueError(f"unexpected input at {pos}")


class Parser:
    def __init__(self, text: str):
        self.toks = list(tokenize(text))
        self.i = 0

    def peek(self):
        return self.toks[self.i] if self.i < len(self.toks) else (None, None)

    def take(self, value=None):
        tok = self.toks[self.i]
        if value is not None and tok[1] != value:
            raise ValueError(f"expected {value!r}, got {tok!r}")
        self.i += 1
        return tok

    def value(self):
        kind, v = self.take()
        if kind == "str":
            return _unescape(v[1:-1])
        if kind == "num":
            if v in ("inf", "-inf", "nan"):
                return float(v)
            return int(v, 16) if v.lower().startswith(("0x", "-0x")) else (
                float(v) if any(c in v for c in ".eE") else int(v))
        if kind == "name":
            return {"true": True, "false": False, "nil": None}[v]
        if v == "{":
            return self.table()
        raise ValueError(f"unexpected token {v!r}")

    def table(self):
        d, arr = {}, []
        while True:
            kind, v = self.peek()
            if v == "}":
                self.take()
                break
            if v == "[":
                self.take()
                key = self.value()
                self.take("]")
                self.take("=")
                d[key] = self.value()
            elif kind == "name" and self.toks[self.i + 1][1] == "=":
                self.take()
                self.take("=")
                d[v] = self.value()
            else:
                arr.append(self.value())
            if self.peek()[1] in (",", ";"):
                self.take()
        for n, item in enumerate(arr, 1):
            d[n] = item
        if d and all(isinstance(k, int) for k in d) and sorted(d) == list(range(1, len(d) + 1)):
            return [d[k] for k in range(1, len(d) + 1)]
        return d

    def assignments(self):
        result = {}
        while self.i < len(self.toks):
            _, name = self.take()
            self.take("=")
            result[name] = self.value()
        return result


# --------------------------------------------------------------------------
# Annotation generation
# --------------------------------------------------------------------------
TYPES = {"bool": "boolean", "cstring": "string", "luaIndex": "number", "time_t": "number",
         "size": "number", "uiUnit": "number", "BigUInteger": "number", "BigInteger": "number",
         "fileID": "number", "normalizedValue": "number", "SimpleFrame": "Frame",
         "SimpleTexture": "Texture", "SimpleFontString": "FontString", "SimpleButton": "Button"}


def as_list(v):
    if v is None:
        return []
    if isinstance(v, dict):
        return [v[k] for k in sorted(v, key=str)]
    return v


def lua_type(field: dict, enums: set) -> str:
    t = field.get("Type") or "any"
    if t == "table" and field.get("InnerType"):
        inner = lua_type({"Type": field["InnerType"]}, enums)
        t = inner + "[]"
    elif field.get("Mixin"):
        t = field["Mixin"]
    elif t in TYPES:
        t = TYPES[t]
    elif t in enums:
        t = "Enum." + t
    if field.get("Nilable"):
        t += "?"
    return t


def doc_lines(item: dict) -> list[str]:
    docs = as_list(item.get("Documentation"))
    return ["---" + "; ".join(str(d) for d in docs), "---"] if docs else []


def gen_function(func: dict, owner: str | None, enums: set, method: bool = False) -> str:
    lines = doc_lines(func)
    flags = [k for k in ("IsProtectedFunction", "HasRestrictions", "SecretArguments",
                         "SecretReturns", "MayReturnNothing") if func.get(k)]
    if flags:
        lines.append("--- " + ", ".join(f"{k}={func[k]}" for k in flags))
    args = as_list(func.get("Arguments"))
    for a in args:
        default = f" Default = {json.dumps(a['Default'])}" if "Default" in a else ""
        lines.append(f"---@param {a.get('Name', '_')} {lua_type(a, enums)}{default}")
    for r in as_list(func.get("Returns")):
        lines.append(f"---@return {lua_type(r, enums)} {r.get('Name', '')}".rstrip())
    sep = ":" if method else "."
    full = f"{owner}{sep}{func['Name']}" if owner else func["Name"]
    lines.append(f"function {full}({', '.join(a.get('Name', '_') for a in args)}) end")
    return "\n".join(lines)


def gen_table(t: dict, enums: set) -> str | None:
    kind = t.get("Type")
    if kind == "Structure":
        lines = [f"---@class {t['Name']}"]
        for f in as_list(t.get("Fields")):
            lines.append(f"---@field {f.get('Name')} {lua_type(f, enums)}")
        return "\n".join(lines)
    if kind == "CallbackType":
        args = ", ".join(f"{a.get('Name')}: {lua_type(a, enums)}" for a in as_list(t.get("Arguments")))
        return f"---@alias {t['Name']} fun({args})"
    if kind == "Constants":
        lines = [f"--- Constants.{t['Name']}"]
        for v in as_list(t.get("Values")):
            lines.append(f"---   {v.get('Name')} = {v.get('Value')} ({v.get('Type')})")
        return "\n".join(lines)
    return None  # Enumerations are emitted from the live Enum table


def sanitize(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]", "_", name)


def write(path: str, text: str):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)


def ketho_names() -> tuple[set, set]:
    """Function names and event names defined in Ketho's annotations."""
    funcs, events = set(), set()
    fre = re.compile(r"^function ([A-Za-z_][\w.:]*)\(", re.M)
    for path in glob.glob(os.path.join(KETHO, "**", "*.lua"), recursive=True):
        with open(path, encoding="utf-8", errors="replace") as fh:
            text = fh.read()
        funcs.update(fre.findall(text))
        if path.endswith(os.path.join("Data", "Event.lua")):
            events.update(re.findall(r'"([A-Z][A-Z0-9_]+)"', text))
    return funcs, events


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if len(sys.argv) > 1:
        src = sys.argv[1]
    else:
        found = glob.glob(os.path.join(ROOT, "WTF", "Account", "*", "SavedVariables", "ForeverAPIDump.lua"))
        if not found:
            sys.exit("No ForeverAPIDump.lua SavedVariables found. Run /apidump in game, then /reload.")
        src = max(found, key=os.path.getmtime)
    print("Reading", src)
    with open(src, encoding="latin-1") as fh:  # bytes 1:1; strings are re-decoded as UTF-8
        db = Parser(fh.read()).assignments().get("ForeverAPIDumpDB")
    if not db:
        sys.exit("ForeverAPIDumpDB is empty. Run /apidump in game, then /reload.")

    meta = db.get("meta", {})
    header = (f"---@meta\n-- Generated by tools/forever-api/convert.py from the live client\n"
              f"-- Build {meta.get('version')} ({meta.get('build')}), toc {meta.get('toc')}, "
              f"project {meta.get('projectID')}\n\n")
    ann = os.path.join(OUT, "Annotations")
    os.makedirs(OUT, exist_ok=True)
    write(os.path.join(OUT, "api.json"), json.dumps(db, indent=1, ensure_ascii=False, sort_keys=True))

    live_enum = db.get("Enum") or {}
    enums = set(live_enum)
    documented, events, scriptobject_methods = set(), {}, {}

    # ---- APIDocumentation systems ----
    for system in as_list(db.get("systems")):
        name = system.get("Name") or "Unnamed"
        ns = system.get("Namespace")
        is_widget = system.get("Type") == "ScriptObject"
        parts = []
        funcs = as_list(system.get("Functions"))
        if ns and funcs and not is_widget:
            parts.append(f"{ns} = {{}}")
        if is_widget:
            parts.append(f"---@class {name}\nlocal {name} = {{}}")
        for f in funcs:
            if is_widget:
                parts.append(gen_function(f, name, enums, method=True))
                scriptobject_methods.setdefault(f["Name"], (name, f))
            else:
                parts.append(gen_function(f, ns, enums))
                documented.add(f"{ns}.{f['Name']}" if ns else f["Name"])
        for t in as_list(system.get("Tables")):
            text = gen_table(t, enums)
            if text:
                parts.append(text)
        for e in as_list(system.get("Events")):
            events[e.get("LiteralName") or e.get("Name")] = (name, e)
        if parts:
            sub = "ScriptObjects" if is_widget else "Systems"
            write(os.path.join(ann, sub, sanitize(name) + ".lua"), header + "\n\n".join(parts) + "\n")

    # ---- Enum ----
    lines = [header + "Enum = {}"]
    for ename in sorted(live_enum):
        values = live_enum[ename]
        if not isinstance(values, dict):
            continue
        lines.append(f"\n---@enum Enum.{ename}\nEnum.{ename} = {{")
        for k, v in sorted(values.items(), key=lambda kv: (str(kv[1]), str(kv[0]))):
            key = k if re.match(r"^[A-Za-z_]\w*$", str(k)) else f"[{json.dumps(k)}]"
            lines.append(f"\t{key} = {json.dumps(v)},")
        lines.append("}")
    write(os.path.join(ann, "Enum.lua"), "\n".join(lines) + "\n")

    # ---- Events ----
    lines = [header + "---@alias FrameEvent", ]
    for ev in sorted(events):
        lines.append(f'---| "{ev}"')
    lines.append("\n-- Payloads")
    for ev in sorted(events):
        system, e = events[ev]
        payload = ", ".join(f"{p.get('Name')}: {lua_type(p, enums)}" for p in as_list(e.get("Payload")))
        lines.append(f"-- {ev}({payload})  [{system}]")
    write(os.path.join(ann, "Event.lua"), "\n".join(lines) + "\n")

    # ---- Widgets (runtime method lists, with signatures where documented) ----
    lines = [header.rstrip()]
    for wname in sorted(db.get("widgets") or {}):
        methods = as_list(db["widgets"][wname])
        lines.append(f"\n---@class {wname}\nlocal {wname} = {{}}")
        for m in methods:
            if m in scriptobject_methods:
                src_name, f = scriptobject_methods[m]
                lines.append(f"-- from {src_name}\n" + gen_function(f, wname, enums, method=True))
            else:
                lines.append(f"-- undocumented\nfunction {wname}:{m}(...) end")
    if db.get("widgetsFailed"):
        lines.append("\n-- Could not create: " + ", ".join(as_list(db["widgetsFailed"])))
    write(os.path.join(ann, "Widgets.lua"), "\n".join(lines) + "\n")

    # ---- Undocumented globals / namespace functions ----
    live = set(as_list(db.get("globalFunctions")))
    for ns, members in (db.get("namespaces") or {}).items():
        if isinstance(members, dict):
            live.update(f"{ns}.{k}" for k, t in members.items() if t == "function")
    undocumented = sorted(live - documented)
    lines = [header + "-- Present in the client (_G) but not described by APIDocumentation.",
             "-- Includes Blizzard FrameXML Lua functions and other addons' globals.\n"]
    for ns in sorted({n.split(".")[0] for n in undocumented if "." in n}):
        lines.append(f"{ns} = {ns} or {{}}")
    lines += [f"function {n}(...) end" for n in undocumented]
    write(os.path.join(ann, "Undocumented.lua"), "\n".join(lines) + "\n")

    # ---- Comparison report vs Ketho ----
    k_funcs, k_events = ketho_names()
    c_live = {n for n in live if n.startswith("C_")}
    c_ketho = {n for n in k_funcs if n.startswith("C_") and ":" not in n}
    only_live = sorted(c_live - c_ketho)
    only_ketho = sorted(c_ketho - c_live)
    ev_only_live = sorted(set(events) - k_events) if k_events else []
    ev_only_ketho = sorted(k_events - set(events)) if k_events else []
    rep = [
        "# Forever API dump report", "",
        f"- Build: {meta.get('version')} ({meta.get('build')}, {meta.get('buildDate')}), "
        f"toc {meta.get('toc')}, WOW_PROJECT_ID {meta.get('projectID')}",
        f"- APIDocumentation: {(db.get('docStatus') or {}).get('result')} — "
        f"{len(as_list(db.get('systems')))} systems, {len(documented)} documented functions, {len(events)} events",
        f"- Live `_G`: {len(as_list(db.get('globalFunctions')))} global functions, "
        f"{len(db.get('namespaces') or {})} `C_*` namespaces, {len(live_enum)} `Enum` tables",
        f"- Undocumented functions (in `_G` but not in APIDocumentation): {len(undocumented)}", "",
        f"## `C_*` functions in Forever but NOT in Ketho's annotations ({len(only_live)})", "",
        *[f"- `{n}`" for n in only_live], "",
        f"## `C_*` functions in Ketho's annotations but NOT in Forever ({len(only_ketho)})", "",
        "Do not use these in Forever addons.", "",
        *[f"- `{n}`" for n in only_ketho], "",
        f"## Events only in Forever ({len(ev_only_live)})", "", *[f"- `{n}`" for n in ev_only_live], "",
        f"## Events only in Ketho's annotations ({len(ev_only_ketho)})", "", *[f"- `{n}`" for n in ev_only_ketho], "",
    ]
    write(os.path.join(OUT, "REPORT.md"), "\n".join(rep))
    print("\n".join(rep[2:7]))
    print(f"C_ functions only in Forever: {len(only_live)}, only in Ketho: {len(only_ketho)}")
    print("Output:", OUT)


if __name__ == "__main__":
    main()
