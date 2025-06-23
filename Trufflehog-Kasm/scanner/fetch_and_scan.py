import requests
import tempfile
import subprocess
import json

def fetch_and_scan(url, debug_log):
    try:
        debug_log.append("Fetching webpage...")
        response = requests.get(url, timeout=10)
        response.raise_for_status()
    except Exception as e:
        msg = f"Failed to fetch {url}: {str(e)}"
        debug_log.append(msg)
        return [{"error": msg}]

    try:
        with tempfile.NamedTemporaryFile(mode='w+', delete=False, suffix=".html") as tmp:
            tmp.write(response.text)
            tmp.flush()
            debug_log.append(f"Saved fetched HTML to temp file: {tmp.name}")

            cmd = [
                'trufflehog',
                'filesystem',
                tmp.name,
                '--results=verified,unknown',
                '--json'
            ]
            debug_log.append(f"Running command: {' '.join(cmd)}")

            result = subprocess.run(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
    except Exception as e:
        msg = f"TruffleHog execution failed: {str(e)}"
        debug_log.append(msg)
        return [{"error": msg}]

    if result.returncode != 0:
        msg = f"TruffleHog error: {result.stderr.strip()}"
        debug_log.append(msg)
        return [{"error": msg}]

    findings = []
    for line in result.stdout.strip().splitlines():
        try:
            findings.append(json.loads(line))
        except json.JSONDecodeError:
            debug_log.append(f"Malformed JSON line: {line}")
            findings.append({"warning": "Malformed output", "raw": line})

    if findings:
        debug_log.append(f"Found {len(findings)} result(s)")
    else:
        debug_log.append("No secrets found.")

    return findings if findings else [{"info": "No secrets found."}]
