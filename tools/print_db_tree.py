#!/usr/bin/env python3
import sqlite3
import os
from typing import Optional, List, Dict, Any


def find_thktree_db() -> Optional[str]:
    device_dir_base = os.path.expanduser("~/Library/Developer/CoreSimulator/Devices")
    if not os.path.exists(device_dir_base):
        print(f"Simulator devices directory not found: {device_dir_base}")
        return None

    candidates: List[str] = []
    for device_uuid in os.listdir(device_dir_base):
        device_dir = os.path.join(device_dir_base, device_uuid)
        if not os.path.isdir(device_dir):
            continue

        data_dir = os.path.join(device_dir, "data", "Containers", "Data", "Application")
        if not os.path.exists(data_dir):
            continue

        for app_dir in os.listdir(data_dir):
            app_path = os.path.join(data_dir, app_dir)
            if not os.path.isdir(app_path):
                continue

            db_path = os.path.join(app_path, "Documents", "thktree", "index.sqlite")
            if os.path.exists(db_path):
                candidates.append(db_path)

    if not candidates:
        return None

    candidates.sort(key=os.path.getmtime, reverse=True)
    return candidates[0]


def main(db_path_arg: Optional[str] = None):
    db_path: Optional[str] = None
    if db_path_arg is not None:
        db_path = os.path.expanduser(db_path_arg)
        if not os.path.exists(db_path):
            print(f"Error: Database file not found at {db_path}")
            return

    if db_path is None:
        print("Searching for index.sqlite in iOS simulators...")
        db_path = find_thktree_db()
        if db_path is None:
            print("Could not find index.sqlite automatically!")
            print("\nPlease provide the path manually:")
            print("  python3 tools/print_db_tree.py <path_to_db>")
            return

    print(f"Using database at: {db_path}")
    print()
    root_dir = os.path.dirname(db_path)

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    print("=== Themes ===")
    cursor.execute("SELECT themeId, title, themePath FROM themes")
    themes = cursor.fetchall()
    for theme_id, title, theme_path in themes:
        resolved_theme_path = resolve_path(root_dir, theme_path)
        print(f"- {title} ({theme_id})")
        print(f"  themePath: {theme_path}")
        print(f"  resolvedThemePath: {resolved_theme_path}")
        print()
        print_tree_for_theme(cursor, root_dir, theme_id)
        print()

    conn.close()


def resolve_path(root_dir: str, path_value: Optional[str]) -> Optional[str]:
    if path_value is None:
        return None
    if os.path.isabs(path_value):
        return path_value
    return os.path.normpath(os.path.join(root_dir, path_value))


def print_tree_for_theme(cursor, root_dir: str, theme_id: str):
    print(f"  === Nodes for theme {theme_id} ===")
    cursor.execute(
        "SELECT nodeId, themeId, parentId, kind, title, createdAt, updatedAt, nodePath, sessionPath FROM nodes WHERE themeId = ?",
        (theme_id,),
    )
    all_nodes = cursor.fetchall()

    id_to_node: Dict[str, Dict[str, Any]] = {}
    parent_to_children: Dict[Optional[str], List[Dict[str, Any]]] = {}

    for row in all_nodes:
        node = {
            "nodeId": row[0],
            "themeId": row[1],
            "parentId": row[2],
            "kind": row[3],
            "title": row[4],
            "createdAt": row[5],
            "updatedAt": row[6],
            "nodePath": row[7],
            "sessionPath": row[8],
        }
        id_to_node[node["nodeId"]] = node
        parent_id = node["parentId"]
        if parent_id not in parent_to_children:
            parent_to_children[parent_id] = []
        parent_to_children[parent_id].append(node)

    def print_node(node: Dict[str, Any], prefix: str):
        node_id = node["nodeId"]
        title = node["title"]
        parent_id = node["parentId"]
        node_path = resolve_path(root_dir, node["nodePath"])
        session_path = resolve_path(root_dir, node["sessionPath"])
        session_exists = os.path.exists(session_path)

        print(f"{prefix}{title} ({node_id})")
        print(f"{prefix}  parent: {parent_id}")
        print(f"{prefix}  kind: {node['kind']}")
        print(f"{prefix}  nodePath: {node['nodePath']}")
        print(f"{prefix}  resolvedNodePath: {node_path}")
        print(f"{prefix}  sessionPath: {node['sessionPath']}")
        print(f"{prefix}  resolvedSessionPath: {session_path}")
        print(f"{prefix}  sessionExists: {session_exists}")

        children = parent_to_children.get(node_id, [])
        for i, child in enumerate(children):
            is_last = i == len(children) - 1
            child_prefix = prefix + ("└── " if is_last else "├── ")
            print_node(child, prefix + ("    " if is_last else "│   "))

    root_nodes = parent_to_children.get(None, [])
    for root in root_nodes:
        print_node(root, "  ")


if __name__ == "__main__":
    import sys

    db_path_arg = None
    if len(sys.argv) >= 2:
        db_path_arg = sys.argv[1]
    main(db_path_arg)
