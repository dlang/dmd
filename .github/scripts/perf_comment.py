#!/usr/bin/env python3
"""Render the perfrunner results.json into a sticky PR comment.

also upserts a single comment identified by a hidden marker so
pushes update one comment instead of spamming.
"""

import json
import os
import sys
import urllib.request

MARKER = "<!-- dmd-perf-bot -->"
THRESHOLDS = {"cachegrind": 0.1, "stat": 0.1, "time -v": 2.0, "wall": 2.0}
DOCS = "https://github.com/%s/blob/master/.github/PERF.md"

TRACE_GATES = {"hello": "compile_hello_debug_instr", "phobos": "compile_phobos_instr"}
TRACE_LABELS = {"hello": "compile hello.d", "phobos": "compile Phobos"}


def delta_pct(base, head):
    return (head - base) / base * 100 if base else 0.0


def fmt_value(value, unit):
    if unit == "count":
        return f"{value / 1e6:,.1f} M"
    if unit == "bytes":
        return f"{value / (1024 * 1024):.2f} MB"
    if unit == "kb":
        mb = value / 1024
        decimals = 2 if mb < 100 else 1 if mb < 1000 else 0
        return f"{mb:.{decimals}f} MB"
    if unit == "us":
        ms = value / 1000
        return f"{ms:,.1f} ms" if ms < 100 else f"{ms:,.0f} ms"
    if unit == "ms":
        return f"{value / 1000:.1f} s"
    return str(value)


def fmt_delta(pct, decimals=2):
    value = f"{abs(pct):.{decimals}f}"
    if float(value) == 0:
        return f"{value}%"
    sign = "+" if pct > 0 else "-"
    return f"{sign}{value}%"


def table(metrics, docs):
    lines = ["| Metric | Base | PR | Δ |", "|--------|-----:|---:|--:|"]
    for m in metrics:
        decimals = 3 if m["method"] == "cachegrind" else 2
        lines.append("| [{}]({}#metrics) | {} | {} | {} |".format(
            m["label"], docs,
            fmt_value(m["base"], m["unit"]),
            fmt_value(m["head"], m["unit"]),
            fmt_delta(delta_pct(m["base"], m["head"]), decimals),
        ))
    return lines


# informational only
def wall_metrics(results):
    rows = []
    for workload, trace in results.get("time_trace", {}).items():
        total = trace["total_us"]
        rows.append({
            "label": TRACE_LABELS.get(workload, workload) + " (wall)",
            "unit": "us", "method": "wall",
            "base": total["base"], "head": total["head"],
        })
    return rows


def attribution(results):
    by_id = {m["id"]: m for m in results["metrics"]}
    total = by_id.get("compile_phobos_instr")
    codegen = by_id.get("compile_phobos_codegen_instr")
    if not total or not codegen:
        return None

    def part(base, head):
        return f"{(head - base) / 1e6:+,.1f} M ({fmt_delta(delta_pct(base, head))})"

    fe_base = total["base"] - codegen["base"]
    fe_head = total["head"] - codegen["head"]
    return "{:+,.1f} M instructions: frontend {}, codegen {}".format(
        (total["head"] - total["base"]) / 1e6,
        part(fe_base, fe_head),
        part(codegen["base"], codegen["head"]))


def breakdown(results, workload):
    lines = [f"<details><summary>Breakdown — {TRACE_LABELS[workload]}</summary>", ""]
    if workload == "phobos":
        line = attribution(results)
        if line:
            lines += [line, ""]

    phases = results["time_trace"][workload]["phases"]
    pairs = [(p, v["base"], v["head"]) for p, v in phases.items() if v["base"] or v["head"]]
    pairs.sort(key=lambda t: abs(t[2] - t[1]), reverse=True)

    lines += ["| Phase (wall, self time) | Base | PR | Δ |", "|-------|-----:|---:|--:|"]
    for name, base, head in pairs:
        lines.append("| {} | {} | {} | {} |".format(
            name, fmt_value(base, "us"), fmt_value(head, "us"),
            fmt_delta(delta_pct(base, head)) if base else "n/a"))
    lines.append("</details>")
    return lines


def render(results, repo):
    docs = DOCS % repo
    metrics = results["metrics"]
    changed = [m for m in metrics
               if abs(delta_pct(m["base"], m["head"])) >= THRESHOLDS.get(m["method"], 0.1)]

    lines = [MARKER, "### DMD perf check", ""]
    if changed:
        lines += table(changed, docs)
    else:
        lines.append("No differences above the noise thresholds.")
    lines.append("")

    changed_ids = {m["id"] for m in changed}
    for workload in results.get("time_trace", {}):
        if TRACE_GATES.get(workload) in changed_ids:
            lines += breakdown(results, workload)
            lines.append("")

    lines += ["<details><summary>All measurements</summary>", ""]
    lines += table(metrics + wall_metrics(results), docs)
    lines += ["</details>", ""]

    lines.append("<sub>{} vs merge-base {} · [about these metrics]({})</sub>".format(
        results["head"]["sha"][:9], results["base"]["sha"][:9], docs))
    return "\n".join(lines) + "\n", bool(changed)


def api(method, url, token, payload=None):
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Accept", "application/vnd.github+json")
    if data:
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read() or "null")


def upsert(body, repo, pr, token, create):
    base = f"https://api.github.com/repos/{repo}"
    comments = api("GET", f"{base}/issues/{pr}/comments?per_page=100", token)
    existing = next((c for c in comments if MARKER in (c.get("body") or "")), None)
    if existing:
        api("PATCH", f"{base}/issues/comments/{existing['id']}", token, {"body": body})
    elif create:
        api("POST", f"{base}/issues/{pr}/comments", token, {"body": body})
    else:
        print("all deltas within noise threshold, skipping comment")
        return
    print(f"upserted comment on {repo}#{pr}")


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: perf_comment.py results.json")

    with open(sys.argv[1]) as f:
        results = json.load(f)

    repo = os.environ.get("REPO")
    body, significant = render(results, repo or "dlang/dmd")
    print(body)

    token = os.environ.get("GITHUB_TOKEN")
    # workflow_run has no PR context, so fall back to the number in results.json.
    pr = os.environ.get("PR_NUMBER") or results["head"].get("pr")
    if not token or not repo or not pr:
        return

    upsert(body, repo, pr, token, significant)


if __name__ == "__main__":
    main()
