#!/usr/bin/env python3
import json
import os
import shutil
import sqlite3
from datetime import datetime, timezone


def find_latest_db():
    device_base = os.path.expanduser("~/Library/Developer/CoreSimulator/Devices")
    candidates = []
    for device_uuid in os.listdir(device_base):
        device_dir = os.path.join(device_base, device_uuid)
        if not os.path.isdir(device_dir):
            continue
        app_base = os.path.join(device_dir, "data", "Containers", "Data", "Application")
        if not os.path.isdir(app_base):
            continue
        for app_uuid in os.listdir(app_base):
            db_path = os.path.join(app_base, app_uuid, "Documents", "thktree", "index.sqlite")
            if os.path.exists(db_path):
                candidates.append(db_path)
    if not candidates:
        raise SystemExit("No index.sqlite found in simulator containers")
    candidates.sort(key=os.path.getmtime, reverse=True)
    return candidates[0]


def load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def rel(root_dir, abs_path):
    return os.path.normpath(os.path.relpath(abs_path, root_dir))


def scan_nodes(theme_id, theme_dir, root_dir):
    rows = []
    nodes_dir = os.path.join(theme_dir, "nodes")
    if not os.path.isdir(nodes_dir):
      return rows

    for current_root, _, filenames in os.walk(nodes_dir):
        if "node.meta.json" not in filenames:
            continue

        meta_path = os.path.join(current_root, "node.meta.json")
        try:
            meta = load_json(meta_path)
        except Exception as e:
            print(f"[skip] malformed node meta: {meta_path}: {e}")
            continue

        if meta.get("themeId") != theme_id:
            print(f"[skip] themeId mismatch: {meta_path}")
            continue

        session_path = os.path.join(current_root, "session.md")
        context_summary_path = os.path.join(current_root, "context_summary.md")
        rows.append(
            {
                "nodeId": meta["nodeId"],
                "themeId": meta["themeId"],
                "parentId": meta.get("parentId"),
                "kind": meta.get("kind", "chat"),
                "title": meta.get("title", meta["nodeId"]),
                "createdAt": meta["createdAt"],
                "updatedAt": meta["updatedAt"],
                "nodePath": rel(root_dir, current_root),
                "sessionPath": rel(root_dir, session_path),
                "contextSummaryPath": rel(root_dir, context_summary_path)
                if os.path.exists(context_summary_path)
                else None,
            }
        )

    rows.sort(key=lambda row: (row["createdAt"], row["nodeId"]))
    return rows


def scan_disk(root_dir):
    themes_dir = os.path.join(root_dir, "themes")
    theme_rows = []
    node_rows = []
    if not os.path.isdir(themes_dir):
        return theme_rows, node_rows

    for entry in sorted(os.listdir(themes_dir)):
        theme_dir = os.path.join(themes_dir, entry)
        if not os.path.isdir(theme_dir):
            continue

        meta_path = os.path.join(theme_dir, "theme.meta.json")
        if not os.path.exists(meta_path):
            continue

        try:
            meta = load_json(meta_path)
        except Exception as e:
            print(f"[skip] malformed theme meta: {meta_path}: {e}")
            continue

        theme_id = meta["themeId"]
        theme_rows.append(
            {
                "themeId": theme_id,
                "title": meta["title"],
                "createdAt": meta["createdAt"],
                "updatedAt": meta["updatedAt"],
                "themePath": rel(root_dir, theme_dir),
            }
        )
        node_rows.extend(scan_nodes(theme_id, theme_dir, root_dir))

    return theme_rows, node_rows


def repair_db(db_path):
    root_dir = os.path.dirname(db_path)
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    backup_path = f"{db_path}.bak.{timestamp}"
    shutil.copy2(db_path, backup_path)

    theme_rows, node_rows = scan_disk(root_dir)

    conn = sqlite3.connect(db_path)
    try:
        cur = conn.cursor()
        cur.execute("BEGIN IMMEDIATE")
        cur.execute("DELETE FROM nodes")
        cur.execute("DELETE FROM themes")
        cur.executemany(
            "INSERT INTO themes(themeId, title, createdAt, updatedAt, themePath) VALUES (?, ?, ?, ?, ?)",
            [
                (row["themeId"], row["title"], row["createdAt"], row["updatedAt"], row["themePath"])
                for row in theme_rows
            ],
        )
        cur.executemany(
            "INSERT INTO nodes(nodeId, themeId, parentId, kind, title, createdAt, updatedAt, nodePath, sessionPath, contextSummaryPath) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                (
                    row["nodeId"],
                    row["themeId"],
                    row["parentId"],
                    row["kind"],
                    row["title"],
                    row["createdAt"],
                    row["updatedAt"],
                    row["nodePath"],
                    row["sessionPath"],
                    row["contextSummaryPath"],
                )
                for row in node_rows
            ],
        )
        conn.commit()
    finally:
        conn.close()

    return backup_path, theme_rows, node_rows


def main():
    db_path = find_latest_db()
    backup_path, theme_rows, node_rows = repair_db(db_path)
    print("Repair complete")
    print(f"DB: {db_path}")
    print(f"Backup: {backup_path}")
    print(f"Themes rebuilt: {len(theme_rows)}")
    print(f"Nodes rebuilt: {len(node_rows)}")
    print("Sample theme paths:")
    for row in theme_rows[:5]:
        print(f"- {row['themeId']}: {row['themePath']}")
    print("Sample node paths:")
    for row in node_rows[:5]:
        print(f"- {row['nodeId']}: {row['nodePath']} | {row['sessionPath']}")


if __name__ == "__main__":
    main()
