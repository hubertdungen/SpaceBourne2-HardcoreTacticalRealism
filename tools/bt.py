"""Print a behaviour tree from an sb2dump JSON as an indented outline.

usage: python bt.py <BehaviorTree .uasset.json>
"""
import json
import sys

SKIP = {"TreeAsset", "Children", "Decorators", "DecoratorOps", "Services", "NodeName", "ParentNode",
        "bCreateNodeInstance", "ForceInstancing"}


def short(v):
    if isinstance(v, dict):
        if "ObjectName" in v:
            return v["ObjectName"].split("'")[-2] if "'" in v["ObjectName"] else v["ObjectName"]
        if "SelectedKeyName" in v:
            return "key:" + str(v["SelectedKeyName"])
        return "{" + ", ".join(f"{k}={short(x)}" for k, x in v.items() if k not in ("SelectedKeyType", "SelectedKeyID")) + "}"
    if isinstance(v, list):
        return "[" + ", ".join(short(x) for x in v) + "]"
    return str(v)


def main(path):
    exports = json.load(open(path, encoding="utf-8"))
    by_name = {e["Name"]: e for e in exports}

    def node(ref):
        if not ref:
            return None
        name = ref["ObjectName"].split(":")[-1].rstrip("'")
        return by_name.get(name)

    def props(e):
        p = e.get("Properties", {})
        return " ".join(f"{k}={short(v)}" for k, v in p.items() if k not in SKIP)

    def show(e, depth, decos=()):
        pad = "  " * depth
        for d in decos:
            de = node(d)
            if de:
                print(f"{pad}@ {de['Type']} {de.get('Properties', {}).get('NodeName', '')} {props(de)}  <{de['Name']}>")
        p = e.get("Properties", {})
        print(f"{pad}{e['Type']} {p.get('NodeName', '')} {props(e)}  <{e['Name']}>")
        for s in p.get("Services", []) or []:
            se = node(s)
            if se:
                print(f"{pad}  $ {se['Type']} {props(se)}  <{se['Name']}>")
        for c in p.get("Children", []) or []:
            child = node(c.get("ChildComposite")) or node(c.get("ChildTask"))
            if child:
                show(child, depth + 1, c.get("Decorators") or [])

    root = exports[0]
    print(root["Name"], props(root))
    show(node(root["Properties"]["RootNode"]), 1)


if __name__ == "__main__":
    main(sys.argv[1])
