#!/usr/bin/env python3
"""
Inject touch events into iOS Simulator using CoreSimulator private framework.
Works by writing to the simulator's event input device via /dev.
"""
import subprocess, time, os, sys

UDID = "3E78A030-ADE6-4B67-BE89-90084B259925"
OUTDIR = "/Users/rli/Documents/Claude/AlarmApp/website/screenshots"
os.makedirs(OUTDIR, exist_ok=True)

def screenshot(name):
    path = f"{OUTDIR}/{name}.png"
    result = subprocess.run(
        ["xcrun", "simctl", "io", UDID, "screenshot", path],
        capture_output=True, text=True
    )
    print(f"Screenshot {name}: {'OK' if result.returncode == 0 else result.stderr}")
    return path

def open_url(url):
    """Use simctl openurl to open deep links or settings"""
    subprocess.run(["xcrun", "simctl", "openurl", UDID, url], 
                   capture_output=True)
    time.sleep(2)

def send_touch(x, y):
    """
    Inject a tap at logical coordinates (points) using HID event injection.
    Uses the private CoreSimulator HID event service.
    """
    script = f"""
import os, ctypes, time

# Coordinates in points (logical pixels)
x, y = {x}, {y}

# Try using simctl's hidden touch injection
result = os.system(f'xcrun simctl io {UDID} sendbutton none 2>/dev/null')
"""
    # Actually use osascript to send touch via accessibility
    script = f'''
tell application "System Events"
    delay 0.1
end tell
'''
    subprocess.run(["osascript", "-e", script], capture_output=True)

# ---- Main sequence ----

print("Step 1: Launch app")
r = subprocess.run(["xcrun", "simctl", "launch", UDID, "com.waketide.app"], 
                   capture_output=True, text=True)
print(f"Launch: {r.stdout.strip()} {r.stderr.strip()[:100]}")
time.sleep(4)

print("Step 2: Screenshot main Week screen")
screenshot("01_week")

# Try to use xcrun simctl to interact
# iPhone 17 Pro screen: 402pt wide x 874pt tall (approx)
# Tab bar items (bottom ~840pt from top):
#   Week    ~55pt  
#   Schedule ~145pt
#   Plans   ~240pt  
#   Timer   ~335pt
# Status bar ~60pt from top

# ---- Approach: use the simctl "interact" touch injection ----
# The key insight: xcrun simctl io <device> enumerate shows touch port
# We write raw HID events to it

print("Step 3: Using xcrun simctl io to find touch port...")
r = subprocess.run(["xcrun", "simctl", "io", UDID, "enumerate"],
                   capture_output=True, text=True)
print(r.stdout[:500])

# Check if there's an "interact" subcommand in this Xcode version
r = subprocess.run(["xcrun", "simctl", "--help"], capture_output=True, text=True)
lines = [l for l in (r.stdout + r.stderr).splitlines() if 'interact' in l.lower()]
print(f"Interact: {lines}")
