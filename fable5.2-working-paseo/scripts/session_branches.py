#!/usr/bin/env python3
"""只读：看一个 Claude 会话文件（.jsonl）里的分支。
  session_branches.py branches <文件> <主干叶子的时间戳片段> [从哪个时间起]    主干以外的各条分支：起止、条数、模型、目录、第一句用户的话
  session_branches.py chain    <文件> <叶子的时间戳片段> [从哪个时间起] [每条最多几个字]   这条链上：用户的话（U）、系统/别的会话送来的（S）、我的文字回复（A）"""
import collections, json, sys


def load(path):
    nodes = {}
    with open(path, errors="replace") as fh:
        for line in fh:
            try:
                d = json.loads(line)
            except ValueError:
                continue
            u = d.get("uuid")
            if not u:
                continue
            m = d.get("message") or {}
            c = m.get("content")
            text, tool = "", "toolUseResult" in d
            if isinstance(c, str):
                text = c
            elif isinstance(c, list):
                text = "\n".join(x.get("text", "") for x in c if isinstance(x, dict) and x.get("type") == "text")
                tool = tool or any(isinstance(x, dict) and x.get("type") == "tool_result" for x in c)
            nodes[u] = {"ts": d.get("timestamp") or "", "type": d.get("type"), "parent": d.get("parentUuid") or d.get("logicalParentUuid"),
                        "model": m.get("model"), "text": text, "tool": tool, "meta": bool(d.get("isMeta")), "side": bool(d.get("isSidechain")),
                        "cwd": d.get("cwd") or ""}
    return nodes


def chain(nodes, u):
    out, seen = [], set()
    while u in nodes and u not in seen:
        seen.add(u)
        out.append(u)
        u = nodes[u]["parent"]
    return out[::-1]


def leaf_at(nodes, leaves, piece):
    hits = [u for u in leaves if piece in nodes[u]["ts"]]
    if len(hits) != 1:
        sys.exit(f"时间戳片段 {piece!r} 对上了 {len(hits)} 个叶子")
    return hits[0]


def said(n):
    return n["type"] == "user" and not n["tool"] and n["text"].strip()


def main():
    cmd, path, piece = sys.argv[1], sys.argv[2], sys.argv[3]
    since = sys.argv[4] if len(sys.argv) > 4 else ""
    nodes = load(path)
    parents = {n["parent"] for n in nodes.values()}
    leaves = [u for u in nodes if u not in parents]
    trunk = chain(nodes, leaf_at(nodes, leaves, piece))
    if cmd == "chain":
        width = int(sys.argv[5]) if len(sys.argv) > 5 else 500
        for u in trunk:
            n = nodes[u]
            if n["ts"] < since or not n["text"].strip() or n["tool"]:
                continue
            t = " ".join(n["text"].split())
            if n["type"] == "user":
                kind = "S" if (n["meta"] or t.startswith(("<paseo-system>", "<system-reminder>", "[SYSTEM NOTIFICATION", "<task-notification>", "<cross-session"))
                               or "<paseo-system>" in t[:80]) else "U"
                print(f"{kind} {n['ts'][5:16]}  {t[:width if kind == 'U' else min(width, 260)]}")
            elif n["type"] == "assistant" and len(t) >= 160:
                print(f"A {n['ts'][5:16]}  {t[:width]}")
        return
    on = set(trunk)
    seen = {}
    for u in leaves:
        if nodes[u]["ts"] < since:
            continue
        c = chain(nodes, u)
        i = next((k for k, x in enumerate(c) if x not in on), None)
        if i is None:
            continue
        b = c[i:]
        if b[0] not in seen or len(b) > len(seen[b[0]]):
            seen[b[0]] = b
    print(f"主干 {len(trunk)} 条（到 {nodes[trunk[-1]]['ts'][5:19]}）；主干以外从 {since or '头'} 起的分支 {len(seen)} 条")
    for b in sorted(seen.values(), key=lambda b: nodes[b[0]]["ts"]):
        models = collections.Counter(nodes[x]["model"] for x in b if nodes[x]["model"])
        cwd = collections.Counter(nodes[x]["cwd"] for x in b if nodes[x]["cwd"]).most_common(1)
        first = next((" ".join(nodes[x]["text"].split()) for x in b if said(nodes[x]) and not nodes[x]["meta"]), "")
        if "</system-reminder>" in first:
            first = first.rsplit("</system-reminder>", 1)[1].strip()
        print(f"{nodes[b[0]]['ts'][5:16]} → {nodes[b[-1]]['ts'][5:16]}  {len(b):5d} 条  {'旁链 ' if nodes[b[0]]['side'] else ''}"
              f"{dict(models.most_common(2))}  {cwd[0][0][-38:] if cwd else ''}  | {first[:70]}")


if __name__ == "__main__":
    main()
