"""Minimal MCP stdio client for the toje emulator (teo-mcp module).

The launcher is the INSTALLED toje plugin, latest version, resolved from the
Claude Code plugin cache (decision 22/08/2026 : one source of truth, the
official plugin). TOJE_MCP stays as an override for plugin development —
point it at <toje clone>/scripts/toje-mcp.sh. Beware when overriding : the
clone and the plugin declare the same Maven version, their builds overwrite
each other's jars in ~/.m2.
"""
import atexit, glob, json, os, subprocess

PLUGIN_GLOB = os.path.expanduser(
    "~/.claude/plugins/cache/wide-dot-thomson/toje/*/scripts/toje-mcp.sh")


def _plugin_launcher():
    """Latest installed plugin version (numeric sort : 1.10 > 1.9)."""
    def vkey(path):
        v = path.split("/toje/")[1].split("/")[0]
        return [int(p) if p.isdigit() else 0 for p in v.split(".")]
    found = sorted(glob.glob(PLUGIN_GLOB), key=vkey)
    return found[-1] if found else None


class Toje:
    def __init__(self):
        launcher = os.environ.get("TOJE_MCP") or _plugin_launcher()
        if not launcher:
            raise SystemExit("no toje plugin installed (looked at %s) and "
                             "TOJE_MCP is not set" % PLUGIN_GLOB)
        self.proc = subprocess.Popen([launcher], stdin=subprocess.PIPE,
                                     stdout=subprocess.PIPE,
                                     stderr=subprocess.DEVNULL, text=True)
        # The JVM must not outlive the probe script : a leaked instance per
        # run is how a debugging session ends up with a hundred of them.
        atexit.register(self.close)
        self.rid = 0
        self.request("initialize", {"protocolVersion": "2024-11-05",
                                    "capabilities": {},
                                    "clientInfo": {"name": "toje-bench", "version": "0"}})
        self.send({"jsonrpc": "2.0", "method": "notifications/initialized"})

    def send(self, obj):
        self.proc.stdin.write(json.dumps(obj) + "\n")
        self.proc.stdin.flush()

    def request(self, method, params):
        self.rid += 1
        self.send({"jsonrpc": "2.0", "id": self.rid, "method": method, "params": params})
        while True:
            line = self.proc.stdout.readline()
            if not line:
                raise RuntimeError("toje-mcp closed stdout")
            msg = json.loads(line)
            if msg.get("id") == self.rid:
                if "error" in msg:
                    raise RuntimeError(f"{method}: {msg['error']}")
                return msg["result"]

    def call(self, name, args=None):
        args = dict(args or {})
        # TOJE_FAST=1 : chaque run_frames passe en TURBO (exécution débridée
        # sans rendu — mêmes instructions, mêmes cycles ; voir run_frames dans
        # teo-mcp). Opt-in par environnement pour que les lanes restent
        # compatibles avec un toje antérieur au paramètre.
        if name == "run_frames" and os.environ.get("TOJE_FAST") == "1":
            args.setdefault("fast", True)
        res = self.request("tools/call", {"name": name, "arguments": args})
        txt = "".join(c.get("text", "") for c in res.get("content", []))
        # A tool-level error (isError) MUST raise. Swallowing it cost two
        # debugging sessions : probes passing timeout_ms=900000 (schema max is
        # 600000) had every run_frames silently rejected — the machine never
        # advanced, which looked exactly like a game freeze (the phantom
        # "stage 7 freeze" of 22/08/2026).
        if res.get("isError"):
            raise RuntimeError(f"{name}: {txt}")
        try:
            return json.loads(txt)
        except Exception:
            return {"raw": txt}

    # --- conveniences -----------------------------------------------------

    def read(self, addr, length):
        """read_memory as a list of ints"""
        r = self.call("read_memory", {"addr": addr, "len": length})
        return [int(x, 16) for x in r["bytes"]]

    def press(self, scancode="0F", hold=5):
        """press and release a key, running frames so the monitor scans it"""
        self.call("press_key", {"scancode": scancode, "down": True})
        self.call("run_frames", {"n": hold})
        self.call("press_key", {"scancode": scancode, "down": False})

    def boot_floppy(self, image):
        """the /toje-boot sequence: reset, menu, key B, let the media start.

        The exact 90/5/120 frame pacing is the one every validated run used ;
        a press occasionally misses the matrix scan, so verify the boot WROTE
        something (game-mode RAM changed against a baseline — the init
        pattern can look like content, never guess it) and retry the key."""
        self.call("mount_disk", {"path": image})
        self.call("reset")
        self.call("run_frames", {"n": 90})
        baseline = self.read("6100", 16)
        for _ in range(3):
            self.press("0F")                  # 'B' : boot from floppy
            self.call("run_frames", {"n": 300})
            if self.read("6100", 16) != baseline:
                return                        # the boot wrote here : loaded
        # three presses without a load ; caller's timeouts will say more

    def dump(self, tag=""):
        """engine log block ($9EF0), registers and disassembly at PC"""
        b = self.read("9EF0", 16)
        code = (b[0] << 8) | b[1]
        print(f"{tag}log.block: code={code:04X} page={b[2]:02X} "
              f"pc={(b[3] << 8) | b[4]:04X} D={(b[5] << 8) | b[6]:04X} "
              f"X={(b[7] << 8) | b[8]:04X} Y={(b[9] << 8) | b[10]:04X} "
              f"U={(b[11] << 8) | b[12]:04X}", flush=True)
        regs = self.call("read_registers")
        print(f"{tag}registers: {regs}", flush=True)
        pc = regs.get("pc")
        if pc:
            print(self.call("disassemble", {"addr": pc, "lines": 8}), flush=True)

    def close(self):
        if self.proc.poll() is None:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.proc.kill()
