#!/usr/bin/env python3
import os
from glob import glob
import sys


def _auto_discover_themes_dir():
    candidates = []

    home = os.path.expanduser("~")
    dev_dir = os.path.join(home, "Library", "Developer", "CoreSimulator", "Devices")
    if os.path.isdir(dev_dir):
        for device in os.listdir(dev_dir):
            data_dir = os.path.join(dev_dir, device, "data", "Containers", "Data", "Application")
            if not os.path.isdir(data_dir):
                continue
            for app_uuid in os.listdir(data_dir):
                thktree = os.path.join(data_dir, app_uuid, "Documents", "thktree")
                themes = os.path.join(thktree, "themes")
                if os.path.isdir(themes):
                    stat = os.stat(thktree)
                    candidates.append((-stat.st_mtime, themes))

    if candidates:
        candidates.sort()
        return candidates[0][1]
    return None


def main():
    themes_dir = None
    if len(sys.argv) >= 2:
        themes_dir = sys.argv[1]
    else:
        print('Trying to auto-discover thktree/themes in iOS simulator...')
        themes_dir = _auto_discover_themes_dir()
        if themes_dir:
            print('Auto-discovered:', themes_dir)

    if not themes_dir:
        print('Could not auto-discover, please specify explicitly:')
        print('  python tools/fix_stale_streaming.py <themes_dir>')
        return 1

    if not os.path.isdir(themes_dir):
        print('Not a directory:', themes_dir)
        return 1

    marker1 = b'\n<!-- streaming -->\n'
    marker2 = b'<!-- streaming -->\n'

    fixed_count = 0
    all_files = glob(os.path.join(themes_dir, '**', 'session.md'), recursive=True)

    for session_md in all_files:
        try:
            with open(session_md, 'rb') as f:
                data = f.read()
        except OSError as e:
            print('skip read failed:', session_md, e)
            continue

        updated = data
        found = False

        if marker1 in updated:
            updated = updated.replace(marker1, b'')
            found = True
        elif marker2 in updated:
            updated = updated.replace(marker2, b'')
            found = True

        if not found:
            continue

        if updated.endswith(b'\n\n'):
            updated = updated.rstrip(b'\n') + b'\n'
        elif not updated.endswith(b'\n'):
            updated = updated + b'\n'

        tmp = session_md + '.tmp'
        try:
            with open(tmp, 'wb') as f:
                f.write(updated)
            os.rename(tmp, session_md)
            print('fixed:', session_md)
            fixed_count += 1
        except OSError as e:
            print('failed to write:', session_md, e)
            try:
                os.unlink(tmp)
            except OSError:
                pass

    print('total fixed:', fixed_count)
    return 0


if __name__ == '__main__':
    sys.exit(main())
