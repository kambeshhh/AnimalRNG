import json, os, sys

TR = r"C:\Users\admin\.claude\projects\C--Users-admin\29c641a9-4af6-4155-85c1-a6638527151c\tool-results"
CHUNKS = ["mcp-Roblox_Studio-execute_luau-1795173759595-0tl9vj.txt",
          "mcp-Roblox_Studio-execute_luau-1795173770619-6q23ur.txt",
          "mcp-Roblox_Studio-execute_luau-1795173771424-6zlcnq.txt"]
ROOT = sys.argv[1]
EXT = {"Script": ".server.luau", "LocalScript": ".client.luau", "ModuleScript": ".luau"}

s = ""
for c in CHUNKS:
    t = open(os.path.join(TR, c), encoding="utf-8").read()
    assert t.startswith("BEGIN"), c
    end = t.rfind("END")
    s += t[5:end]
items = json.loads(s)
for it in items:
    parts = it["path"]
    base = os.path.join(ROOT, *parts[:-1])
    name = parts[-1]
    if it["hasChildren"]:
        base = os.path.join(base, name); name = "init"
    os.makedirs(base, exist_ok=True)
    p = os.path.join(base, name + EXT[it["class"]])
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write(it["source"])
    print(os.path.relpath(p, ROOT), len(it["source"]))
print("TOTAL", len(items))
