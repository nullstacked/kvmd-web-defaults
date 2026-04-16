#!/bin/bash
set -e

LOG_PREFIX="kvmd-web-defaults"
WEB_DIR="/usr/share/kvmd/web"
JS_DIR="$WEB_DIR/share/js/kvm"

log() { echo "[$LOG_PREFIX] $*"; }
warn() { echo "[$LOG_PREFIX] WARNING: $*" >&2; }

PATCHED=0
SKIPPED=0
FAILED=0

patch_ok()   { log "PATCHED: $1"; PATCHED=$((PATCHED + 1)); }
patch_skip() { log "SKIPPED (already applied): $1"; SKIPPED=$((SKIPPED + 1)); }
patch_fail() { warn "FAILED: $1"; FAILED=$((FAILED + 1)); }

# ============================================================
# Step 1: Ensure tools.config helper exists in tools.js
# ============================================================
patch_tools_js() {
    local path="$WEB_DIR/share/js/tools.js"
    if [ ! -f "$path" ]; then
        warn "tools.js not found at $path"
        return 1
    fi

    if grep -q "config:" "$path" && grep -q "getBool" "$path"; then
        patch_skip "tools.js (config helper)"
        return 0
    fi

    # Add config namespace to tools object using Python for safe insertion
    python3 << PYEOF
import sys

path = "$path"
with open(path, "r") as f:
    content = f.read()

if "config:" in content and "getBool" in content:
    sys.exit(0)

config_helper = '''
\tconfig: {
\t\tget: function(prop, fallback) {
\t\t\tlet val = getComputedStyle(document.documentElement).getPropertyValue("--" + prop).trim();
\t\t\tif (val === "" || val === undefined) return fallback;
\t\t\t// Try numeric
\t\t\tif (!isNaN(val) && val !== "") return Number(val);
\t\t\treturn val;
\t\t},
\t\tgetBool: function(prop, fallback) {
\t\t\tlet val = getComputedStyle(document.documentElement).getPropertyValue("--" + prop).trim();
\t\t\tif (val === "" || val === undefined) return fallback;
\t\t\treturn (val === "true" || val === "1" || val === "yes");
\t\t},
\t},
'''

# Find the tools export object - look for "export var tools = {" or similar
# Insert the config block inside the tools object
import re

# Try to find the tools object opening
match = re.search(r'(export\s+var\s+tools\s*=\s*\{)', content)
if not match:
    match = re.search(r'(var\s+tools\s*=\s*\{)', content)
if not match:
    # Try "tools = {"
    match = re.search(r'(tools\s*=\s*\{)', content)

if match:
    insert_pos = match.end()
    content = content[:insert_pos] + "\n" + config_helper + content[insert_pos:]
    with open(path, "w") as f:
        f.write(content)
    print("PATCHED")
else:
    print("FAILED: could not find tools object", file=sys.stderr)
    sys.exit(1)
PYEOF

    if [ $? -eq 0 ]; then
        patch_ok "tools.js (config helper)"
    else
        patch_fail "tools.js (config helper)"
    fi
}

# ============================================================
# Step 2: Ensure /etc/kvmd/web.css is linked in index.html
# ============================================================
patch_index_html() {
    local path="$WEB_DIR/kvm/index.html"
    if [ ! -f "$path" ]; then
        warn "index.html not found at $path"
        return 1
    fi

    if grep -q "web.css" "$path"; then
        patch_skip "index.html (web.css link)"
        return 0
    fi

    python3 << PYEOF
path = "$path"
with open(path, "r") as f:
    content = f.read()

if "web.css" in content:
    exit(0)

# Insert CSS link after last existing stylesheet link
last_css = content.rfind('<link rel="stylesheet"')
if last_css >= 0:
    eol = content.find("\n", last_css)
    if eol >= 0:
        css_link = '\n\t\t<link rel="stylesheet" href="/etc/kvmd/web.css" onerror="this.remove()">'
        content = content[:eol] + css_link + content[eol:]
        with open(path, "w") as f:
            f.write(content)
        print("PATCHED")
    else:
        exit(1)
else:
    exit(1)
PYEOF

    if [ $? -eq 0 ]; then
        patch_ok "index.html (web.css link)"
    else
        patch_fail "index.html (web.css link)"
    fi
}

# ============================================================
# Step 3: Patch JS files with tools.config.getBool/get calls
# ============================================================
patch_js_files() {
    python3 << 'PYEOF'
import sys
import os

WEB_DIR = "/usr/share/kvmd/web"
JS_DIR = os.path.join(WEB_DIR, "share", "js", "kvm")

patched = 0
skipped = 0
failed = 0

def log(msg):
    print(f"[kvmd-web-defaults] {msg}")

def patch_ok(name):
    global patched
    log(f"PATCHED: {name}")
    patched += 1

def patch_skip(name):
    global skipped
    log(f"SKIPPED (already applied): {name}")
    skipped += 1

def patch_fail(name, err=""):
    global failed
    log(f"FAILED: {name} {err}")
    failed += 1

def read_file(path):
    with open(path, "r") as f:
        return f.read()

def write_file(path, content):
    with open(path, "w") as f:
        f.write(content)

def safe_replace(content, old, new):
    """Replace old with new only if old exists and new doesn't already exist."""
    if new in content:
        return content, False  # Already applied
    if old not in content:
        return content, None  # Pattern not found
    content = content.replace(old, new, 1)
    return content, True

# Define all replacements: (filename, old, new)
replacements = [
    # atx.js
    ("atx.js", [
        ('bindSimpleSwitch($("atx-ask-switch"), "atx.ask", true)',
         'bindSimpleSwitch($("atx-ask-switch"), "atx.ask", tools.config.getBool("kvm--atx-ask", true))'),
    ]),
    # hid.js
    ("hid.js", [
        ('"hid.sysrq.ask", true)',
         '"hid.sysrq.ask", tools.config.getBool("kvm--hid-sysrq-ask", true))'),
    ]),
    # keyboard.js
    ("keyboard.js", [
        ('"hid.keyboard.bad_link", false)',
         '"hid.keyboard.bad_link", tools.config.getBool("kvm--hid-keyboard-bad-link", false))'),
        ('"hid.keyboard.swap_cc", false)',
         '"hid.keyboard.swap_cc", tools.config.getBool("kvm--hid-keyboard-swap-cc", false))'),
    ]),
    # main.js
    ("main.js", [
        ('"page.close.ask", true,',
         '"page.close.ask", tools.config.getBool("kvm--page-close-ask", true),'),
    ]),
    # mouse.js
    ("mouse.js", [
        ('"hid.mouse.squash", true)',
         '"hid.mouse.squash", tools.config.getBool("kvm--hid-mouse-squash", true))'),
        ('"hid.mouse.reverse_scrolling", false)',
         '"hid.mouse.reverse_scrolling", tools.config.getBool("kvm--hid-mouse-reverse-scrolling", false))'),
        ('"hid.mouse.reverse_panning", false)',
         '"hid.mouse.reverse_panning", tools.config.getBool("kvm--hid-mouse-reverse-panning", false))'),
        ('"hid.mouse.cumulative_scrolling", cumulative_scrolling)',
         '"hid.mouse.cumulative_scrolling", tools.config.getBool("kvm--hid-mouse-cumulative-scrolling", cumulative_scrolling))'),
        ('"hid.mouse.dot", true,',
         '"hid.mouse.dot", tools.config.getBool("kvm--hid-mouse-dot", true),'),
    ]),
    # paste.js
    ("paste.js", [
        ('"hid.pak.ask", true)',
         '"hid.pak.ask", tools.config.getBool("kvm--hid-pak-ask", true))'),
        ('"hid.pak.secure", false,',
         '"hid.pak.secure", tools.config.getBool("kvm--hid-pak-secure", false),'),
    ]),
    # stream.js
    ("stream.js", [
        ('tools.storage.get("stream.orient", 0)',
         'tools.storage.get("stream.orient", tools.config.get("kvm--stream-orient", 0))'),
        ('"stream.mic", false,',
         '"stream.mic", tools.config.getBool("kvm--stream-mic", false),'),
        ('"stream.cam", false,',
         '"stream.cam", tools.config.getBool("kvm--stream-cam", false),'),
        ('"stream.suspend", false,',
         '"stream.suspend", tools.config.getBool("kvm--stream-suspend", false),'),
        ('tools.storage.get("stream.mode", "janus")',
         'tools.storage.get("stream.mode", tools.config.get("kvm--stream-mode", "janus"))'),
    ]),
    # switch.js
    ("switch.js", [
        ('"switch.atx.ask", true)',
         '"switch.atx.ask", tools.config.getBool("kvm--switch-atx-ask", true))'),
        ('"switch.msd.ask", true)',
         '"switch.msd.ask", tools.config.getBool("kvm--switch-msd-ask", true))'),
    ]),
]

for filename, patches in replacements:
    path = os.path.join(JS_DIR, filename)
    if not os.path.exists(path):
        patch_fail(filename, "(file not found)")
        continue

    try:
        content = read_file(path)
        file_changed = False
        all_already = True
        any_failed = False

        for old, new in patches:
            result_content, did_change = safe_replace(content, old, new)
            if did_change is True:
                content = result_content
                file_changed = True
                all_already = False
            elif did_change is False:
                pass  # Already applied
            else:
                # Pattern not found and not already applied
                if new not in content:
                    log(f"  WARNING: pattern not found in {filename}: {old[:60]}...")
                    any_failed = True
                all_already = False

        if file_changed:
            write_file(path, content)
            patch_ok(filename)
        elif all_already and not any_failed:
            patch_skip(filename)
        elif any_failed:
            patch_fail(filename, "(some patterns not found)")
        else:
            patch_skip(filename)

    except Exception as e:
        patch_fail(filename, str(e))

# Write summary to fd 3 or just print
log(f"JS patches complete: {patched} patched, {skipped} skipped, {failed} failed")
if failed > 0:
    sys.exit(1)
PYEOF
}

# ============================================================
# Main
# ============================================================

# Ensure /etc/kvmd/ directory exists for web.css
mkdir -p /etc/kvmd

patch_tools_js || true
patch_index_html || true
patch_js_files || true

log "Done. Patched=$PATCHED, Skipped=$SKIPPED, Failed=$FAILED"
