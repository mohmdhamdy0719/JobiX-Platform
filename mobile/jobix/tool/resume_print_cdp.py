"""Minimal local Chromium DevTools pipe; stdlib only, no TCP listener."""
import json
import os
import select
import signal
import subprocess
import time


def tool_environment():
    """Keep runtime boot variables, never forward application credentials."""
    allowed = (
        "PATH", "HOME", "LANG", "LC_ALL", "LD_LIBRARY_PATH", "NIX_LD",
        "NIX_LD_LIBRARY_PATH", "FONTCONFIG_FILE", "FONTCONFIG_PATH",
        "XDG_DATA_DIRS", "XDG_CONFIG_DIRS",
    )
    return {key: os.environ[key] for key in allowed if key in os.environ}


class Chromium:
    def __init__(self, executable, directory):
        child_read, self.writer = os.pipe()
        self.reader, child_write = os.pipe()
        self.buffer = b""
        self.sequence = 0
        self.log = open(directory / "chromium.log", "wb")

        def pipes():
            os.dup2(child_read, 3)
            os.dup2(child_write, 4)
            os.set_inheritable(3, True)
            os.set_inheritable(4, True)

        try:
            self.process = subprocess.Popen(
                [executable, "--headless", "--no-sandbox", "--disable-gpu",
                 "--remote-debugging-pipe", "--disable-background-networking",
                 "--disable-component-update", "--disable-sync", "--no-first-run",
                 "--no-default-browser-check", "--no-proxy-server",
                 "--host-resolver-rules=MAP * ~NOTFOUND",
                 f"--user-data-dir={directory / 'browser-profile'}"],
                preexec_fn=pipes, close_fds=False, start_new_session=True,
                env=tool_environment(),
                stdout=subprocess.DEVNULL, stderr=self.log,
            )
        finally:
            os.close(child_read)
            os.close(child_write)

    def call(self, method, params=None, session=None, timeout=30):
        self.sequence += 1
        request = {"id": self.sequence, "method": method, "params": params or {}}
        if session:
            request["sessionId"] = session
        packet = json.dumps(request).encode() + b"\0"
        while packet:
            packet = packet[os.write(self.writer, packet):]
        deadline = time.monotonic() + timeout
        while True:
            while b"\0" in self.buffer:
                raw, self.buffer = self.buffer.split(b"\0", 1)
                if not raw:
                    continue
                response = json.loads(raw)
                if response.get("id") == request["id"]:
                    if "error" in response:
                        raise RuntimeError(f"DevTools {method}: {response['error']}")
                    return response.get("result", {})
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise RuntimeError(f"DevTools timeout: {method}")
            if select.select([self.reader], [], [], remaining)[0]:
                chunk = os.read(self.reader, 65536)
                if not chunk:
                    raise RuntimeError("Chromium pipe closed; inspect chromium.log")
                self.buffer += chunk

    def evaluate(self, expression, session):
        result = self.call("Runtime.evaluate", {
            "expression": expression, "returnByValue": True, "awaitPromise": True,
        }, session)
        if "exceptionDetails" in result:
            raise RuntimeError("DOM evaluation failed: " + str(result["exceptionDetails"]))
        return result["result"].get("value")

    def close(self):
        try:
            os.killpg(self.process.pid, signal.SIGTERM)
            self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(self.process.pid, signal.SIGKILL)
            self.process.wait()
        finally:
            os.close(self.reader)
            os.close(self.writer)
            self.log.close()
