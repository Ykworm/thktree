#!/usr/bin/env python3
import os
import json
import shutil
import sqlite3

def auto_discover_themes_dir_and_db():
    sim_base = os.path.expanduser("~/Library/Developer/CoreSimulator/Devices")
    if not os.path.exists(sim_base):
        return None, None
    candidates = []
    for dev_name in os.listdir(sim_base):
        dev_path = os.path.join(sim_base, dev_name)
        if not os.path.isdir(dev_path):
            continue
        data_path = os.path.join(dev_path, "data/Containers/Data/Application")
        if not os.path.isdir(data_path):
            continue
        for app_name in os.listdir(data_path):
            app_path = os.path.join(data_path, app_name)
            if not os.path.isdir(app_path):
                continue
            thktree_dir = os.path.join(app_path, "Documents/thktree")
            themes_dir = os.path.join(thktree_dir, "themes")
            db_path = os.path.join(thktree_dir, "index.db")
            if os.path.isdir(themes_dir) and os.path.exists(db_path):
                mtime = os.path.getmtime(thktree_dir)
                candidates.append((mtime, themes_dir, db_path))
    if not candidates:
        return None, None
    candidates.sort(reverse=True)
    return candidates[0][1], candidates[0][2]

def migrate_theme(theme_dir, db_path):
    old_nodes_dir = os.path.join(theme_dir, "nodes")
    if not os.path.exists(old_nodes_dir):
        print("No nodes dir, nothing to do:", theme_dir)
        return
    print("Migrating theme:", theme_dir)
    
    node_info = {}
    for node_name in os.listdir(old_nodes_dir):
        node_dir = os.path.join(old_nodes_dir, node_name)
        if not os.path.isdir(node_dir):
            continue
        meta_path = os.path.join(node_dir, "node.meta.json")
        if not os.path.exists(meta_path):
            continue
        try:
            with open(meta_path, "r", encoding="utf-8") as f:
                meta = json.load(f)
            node_id = meta.get("nodeId")
            parent_id = meta.get("parentId")
            if node_id:
                node_info[node_id] = {
                    "parentId": parent_id,
                    "old_dir": node_dir,
                    "meta": meta,
                    "new_dir": None,
                    "visited": False
                }
        except Exception as e:
            print("Skip bad node:", node_dir, e)
    
    moved = 0
    
    for node_id in list(node_info.keys()):
        info = node_info[node_id]
        if info["visited"]:
            continue
        
        stack = [(node_id, False)]
        while stack:
            curr_id, curr_visited = stack.pop()
            curr_info = node_info.get(curr_id)
            if not curr_info:
                continue
            
            if not curr_visited:
                if curr_info["visited"]:
                    continue
                curr_info["visited"] = True
                stack.append((curr_id, True))
                
                parent_id = curr_info["parentId"]
                if parent_id and parent_id in node_info and not node_info[parent_id]["visited"]:
                    stack.append((parent_id, False))
            else:
                old_dir = curr_info["old_dir"]
                node_name = os.path.basename(old_dir)
                
                parent_id = curr_info["parentId"]
                target_parent_dir = old_nodes_dir
                if parent_id and parent_id in node_info:
                    parent_info = node_info[parent_id]
                    target_parent_dir = parent_info.get("new_dir") or old_nodes_dir
                
                new_dir = os.path.join(target_parent_dir, node_name)
                
                if old_dir != new_dir:
                    print("  moving", curr_id, "->", new_dir)
                    shutil.move(old_dir, new_dir)
                
                curr_info["new_dir"] = new_dir
                moved += 1
    
    print("Migrated", moved, "nodes in", theme_dir)
    
    if db_path:
        print("Updating SQLite DB:", db_path)
        conn = sqlite3.connect(db_path)
        try:
            for node_id, info in node_info.items():
                new_dir = info["new_dir"]
                session_path = os.path.join(new_dir, "session.md")
                conn.execute(
                    '''
                    UPDATE nodes
                    SET nodePath = ?, sessionPath = ?
                    WHERE nodeId = ?
                    ''',
                    (new_dir, session_path, node_id)
                )
            conn.commit()
            print("SQLite updated.")
        except Exception as e:
            print("SQLite update error:", e)
            conn.rollback()
        finally:
            conn.close()

def main():
    import sys
    if len(sys.argv) > 1:
        themes_dir = sys.argv[1]
        db_path = None
        if os.path.isdir(themes_dir):
            thktree_dir = os.path.dirname(themes_dir)
            candidate_db = os.path.join(thktree_dir, "index.db")
            if os.path.exists(candidate_db):
                db_path = candidate_db
    else:
        print("Trying to auto-discover thktree/themes in iOS simulator...")
        themes_dir, db_path = auto_discover_themes_dir_and_db()
        if not themes_dir:
            print("Could not auto-discover themes dir, please specify explicitly.")
            return
        print("Auto-discovered themes dir:", themes_dir)
        if db_path:
            print("Auto-discovered DB:", db_path)
    
    if not os.path.isdir(themes_dir):
        print("Not a directory:", themes_dir)
        return
    
    for theme_name in os.listdir(themes_dir):
        theme_dir = os.path.join(themes_dir, theme_name)
        if not os.path.isdir(theme_dir):
            continue
        migrate_theme(theme_dir, db_path)
    print("Done.")

if __name__ == "__main__":
    main()
