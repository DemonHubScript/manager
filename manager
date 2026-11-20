#!/usr/bin/env python3
# Roblox Manager for Termux (root required)
# Monitors multiple Roblox clones, relaunches dead ones, injects saved
# session config, cleans cache and protects processes from being killed.

import os
import shlex
import subprocess
import time

# ================== CONFIG ==================
TITLE = "ROBLOX MANAGER"
PACKAGES = []             # e.g. ["com.roblox.fizzy", "com.roblox.fizzz"]; empty = auto-detect
PRIVATE_LINK = ""         # private server link; leave empty to use PLACE_ID
PLACE_ID = ""             # game place id; empty = just open the app
CONFIG_DIR = os.path.expanduser("~/roblox_config")  # files: <package>_config.xml
CHECK_INTERVAL = 5        # seconds between status checks
CLEAN_INTERVAL = 1800     # seconds between cache cleans (0 = disabled)
LAUNCH_GRACE = 60         # seconds to wait for a launched app to come online
LAUNCH_GAP = 20           # minimum seconds between two launches (avoids RAM spikes)
ANTI_KILL = True          # set oom_score_adj to -1000 for running clients
RESOLUTION = None         # e.g. (540, 960, 160) = width, height, density; None = untouched
# ============================================

G, R, Y, C, X = "\033[92m", "\033[91m", "\033[93m", "\033[96m", "\033[0m"


def su(cmd, timeout=30):
    try:
        r = subprocess.run(["su", "-c", cmd], capture_output=True,
                           text=True, timeout=timeout)
        return r.stdout.strip()
    except Exception:
        return ""


def installed_roblox():
    out = su("pm list packages | grep roblox")
    return sorted(l.split(":", 1)[1].strip() for l in out.splitlines() if ":" in l)


def is_running(pkg):
    return bool(su(f"pidof {pkg}")) or bool(su(f"ps -A | grep -w {pkg}"))


def inject_config(pkg):
    src = os.path.join(CONFIG_DIR, f"{pkg}_config.xml")
    if not os.path.isfile(src):
        return
    prefs = f"/data/data/{pkg}/shared_prefs"
    dst = f"{prefs}/com.roblox.client.xml"
    uid = su(f"stat -c %u /data/data/{pkg}")
    su(f"mkdir -p {prefs}")
    su(f"cp -f {shlex.quote(src)} {dst}")
    if uid.isdigit():
        su(f"chown {uid}:{uid} {dst}")
    su(f"chmod 660 {dst}; restorecon {dst}")


def launch(pkg):
    if PRIVATE_LINK:
        su(f'am start --user 0 -a android.intent.action.VIEW '
           f'-d {shlex.quote(PRIVATE_LINK)} -p {pkg}')
    elif PLACE_ID:
        su(f'am start --user 0 -a android.intent.action.VIEW '
           f'-d "roblox://placeId={PLACE_ID}" -p {pkg}')
    else:
        su(f"monkey -p {pkg} -c android.intent.category.LAUNCHER 1")


def protect(pkg):
    for pid in su(f"pidof {pkg}").split():
        su(f"echo -1000 > /proc/{pid}/oom_score_adj")


def clean(pkgs):
    for p in pkgs:
        su(f"rm -rf /data/data/{p}/cache/*")
    su("sync; echo 3 > /proc/sys/vm/drop_caches")


def ram_info():
    try:
        info = {}
        with open("/proc/meminfo") as f:
            for line in f:
                k, v = line.split(":", 1)
                info[k] = int(v.split()[0]) // 1024
        total = info["MemTotal"]
        return f"{total - info['MemAvailable']}/{total}MB"
    except Exception:
        return "N/A"


def fmt(sec):
    sec = int(sec)
    return f"{sec // 3600:02d}:{sec % 3600 // 60:02d}:{sec % 60:02d}"


def render(pkgs, status, start, last_clean):
    line = "=" * 44
    print("\033[2J\033[H", end="")
    print(f"{C}{line}{X}")
    print(f"{C}[ {TITLE} ]{X}")
    print(f"{Y}> RAM DEVICE : {ram_info()}{X}")
    print(f"{Y}> LAST CLEAN : {fmt(time.time() - last_clean)} ago{X}")
    print(f"{Y}> TIME       : {fmt(time.time() - start)}{X}")
    print(f"{C}{line}{X}")
    print(f"{'PACKAGE NAME':<30}STATUS")
    print("-" * 44)
    for p in pkgs:
        s = status[p]
        col = G if s == "ONLINE" else (Y if s == "LAUNCHING" else R)
        print(f"{p:<30}{col}{s}{X}")
    print(f"{C}{line}{X}")
    print("Press CTRL+C to stop.")


def main():
    found = installed_roblox()
    pkgs = [p for p in PACKAGES if p in found] if PACKAGES else found
    if not pkgs:
        print("No Roblox packages found. Make sure root access is granted.")
        return
    for p in PACKAGES:
        if p not in found:
            print(f"Package not installed, skipped: {p}")

    if RESOLUTION:
        w, h, d = RESOLUTION
        su(f"wm size {w}x{h}; wm density {d}")

    for p in pkgs:  # kill leftover processes
        su(f"am force-stop {p}")

    start = last_clean = time.time()
    last_launch_any = 0
    grace_until = {p: 0 for p in pkgs}
    oom_done = {p: False for p in pkgs}
    status = {p: "OFFLINE" for p in pkgs}

    try:
        while True:
            now = time.time()
            for p in pkgs:
                if is_running(p):
                    status[p] = "ONLINE"
                    if ANTI_KILL and not oom_done[p]:
                        protect(p)
                        oom_done[p] = True
                elif now < grace_until[p]:
                    status[p] = "LAUNCHING"
                else:
                    status[p] = "OFFLINE"
                    oom_done[p] = False
                    if now - last_launch_any >= LAUNCH_GAP:
                        su(f"am force-stop {p}")
                        inject_config(p)
                        launch(p)
                        grace_until[p] = now + LAUNCH_GRACE
                        last_launch_any = now
                        status[p] = "LAUNCHING"

            if CLEAN_INTERVAL and now - last_clean >= CLEAN_INTERVAL:
                clean(pkgs)
                last_clean = now

            render(pkgs, status, start, last_clean)
            time.sleep(CHECK_INTERVAL)
    except KeyboardInterrupt:
        print("\nStopped.")
    finally:
        if RESOLUTION:
            su("wm size reset; wm density reset")


if _
_name__ == "__main__":
    main()
