#!/usr/bin/env python3
import os

target_node_id = "nd_01KSFZ26GEPJ11J030DAYNPP6P"

sim_base = os.path.expanduser("~/Library/Developer/CoreSimulator/Devices")
if not os.path.exists(sim_base):
    print("sim base not found:", sim_base)
    exit(1)

found = None
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
        themes_dir = os.path.join(app_path, "Documents/thktree/themes")
        if not os.path.isdir(themes_dir):
            continue
        for root, dirs, files in os.walk(themes_dir):
            for filename in files:
                if filename != "session.md":
                    continue
                filepath = os.path.join(root, filename)
                if target_node_id in filepath:
                    print("found:", filepath)
                    with open(filepath, "r", encoding="utf-8") as f:
                        content = f.read()
                        print("--- BEGIN ---")
                        print(content)
                        print("--- END ---")
                    found = filepath
                    break
            if found:
                break
        if found:
            break
if not found:
    print("not found")
