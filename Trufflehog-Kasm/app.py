import os
import json
import subprocess
import tempfile
from datetime import datetime
from urllib.parse import urljoin, urlparse

import pandas as pd
import requests
import streamlit as st
import tldextract
from bs4 import BeautifulSoup

# Page configuration
st.set_page_config(page_title="Trufflehog WebUI", layout="wide")

# Theme selection
theme = st.sidebar.selectbox("Theme:", ["Light", "Dark"], index=1)
if theme == "Dark":
    st.markdown(
        '''
        <style>
        [data-testid="stAppViewContainer"], [data-testid="stSidebar"], .css-18e3th9 {
            background-color: #0E1117 !important;
            color: #FAFAFA !important;
        }
        div.stButton > button { background-color: #333333 !important; color: #FAFAFA !important; }
        input, textarea, select { background-color: #1E1E1E !important; color: #FAFAFA !important; border-color: #555555 !important; }
        ::placeholder { color: #888888 !important; }
        label { color: #FAFAFA !important; }
        div[role="option"] { background-color: #1E1E1E !important; color: #FAFAFA !important; }
        </style>
        ''', unsafe_allow_html=True
    )

st.title("🔍 Trufflehog WebUI")

# Sidebar: Scan mode selection
desc = {
    "Website Scan": "Scan a web page (single), crawl site, or brute-force directories.",
    "Git Repository Scan": "Scan a remote Git repository.",
    "Local Git Repo Scan": "Scan a local Git repository via file:// URI.",
    "GitHub Org Scan": "Scan all repositories in a GitHub organization.",
    "GitHub Repo + Issues/PR Scan": "Scan issue & PR comments on a GitHub repo.",
    "GitHub Experimental Scan": "Experimental scan over hidden commits.",
    "S3 Bucket Scan": "Scan an AWS S3 bucket for secrets.",
    "S3 Bucket with IAM Role": "Scan S3 using an IAM role ARN.",
    "GCS Bucket Scan": "Scan a Google Cloud Storage bucket.",
    "SSH Git Repo Scan": "Scan a repository over SSH.",
    "Filesystem Scan": "Scan local files or directories.",
    "Postman Workspace Scan": "Scan a Postman workspace or collection.",
    "Jenkins Scan": "Scan a Jenkins server.",
    "ElasticSearch Scan": "Scan an Elasticsearch cluster.",
    "HuggingFace Scan": "Scan HuggingFace models, datasets, and spaces."
}
scan_mode = st.sidebar.selectbox("Scan Mode:", list(desc.keys()))
st.sidebar.markdown(f"**Description:** {desc[scan_mode]}")

# Unified TruffleHog runner with optional streaming to file
def run_trufflehog(cmd, out_file_path=None):
    records = []
    if out_file_path:
        os.makedirs(os.path.dirname(out_file_path), exist_ok=True)
        mode = 'a' if os.path.exists(out_file_path) else 'w'
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        with open(out_file_path, mode) as out_f:
            for line in proc.stdout:
                out_f.write(line)
                out_f.flush()
                try:
                    records.append(json.loads(line))
                except:
                    continue
        stderr = proc.stderr.read()
        proc.wait()
        if proc.returncode != 0:
            st.error(f"TruffleHog error: {stderr.strip()}")
        return records
    else:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if proc.returncode != 0:
            st.error(f"TruffleHog error: {proc.stderr.strip()}")
            return []
        for line in proc.stdout.splitlines():
            try:
                records.append(json.loads(line))
            except:
                continue
        return records

# Crawl-and-scan helper that streams results to file
def crawl_and_scan(start_url, max_pages, scope, out_file_path):
    seen, queue, all_results = set(), [start_url], []
    parsed = urlparse(start_url)
    host = parsed.netloc.split(':')[0]
    parts = host.split('.')
    root_domain = '.'.join(parts[-2:]) if len(parts) >= 2 else host

    while queue and len(seen) < max_pages:
        url = queue.pop(0)
        if url in seen:
            continue
        seen.add(url)
        try:
            resp = requests.get(url, timeout=5)
            resp.raise_for_status()
            soup = BeautifulSoup(resp.text, "html.parser")
            for a in soup.find_all('a', href=True):
                link = urljoin(url, a['href'])
                nl = urlparse(link).netloc.split(':')[0]
                if scope == "Root Domain" and tldextract.extract(link).registered_domain != root_domain:
                    continue
                if scope == "Exact Host" and nl != host:
                    continue
                if link not in seen:
                    queue.append(link)
            tmp = tempfile.NamedTemporaryFile(delete=False, suffix='.html')
            tmp.write(resp.text.encode()); tmp.flush()
            cmd = [
                "trufflehog", "filesystem", tmp.name,
                "--results=verified,unknown", "--json", "--no-update"
            ]
            all_results.extend(run_trufflehog(cmd, out_file_path))
        except Exception as e:
            st.warning(f"Failed to fetch {url}: {e}")
    return all_results

# Main logic
records = None

if scan_mode == "Website Scan":
    page_type_descriptions = {
        "Single Page": (
            "Fetches one URL, saves its HTML, and runs TruffleHog’s filesystem scanner. "
            "Good for auditing a single page."
        ),
        "Crawl Entire Site": (
            "Starts from the given URL, follows in-domain links up to your max-pages limit, "
            "saving each page’s HTML and scanning it."
        ),
        "Directory Brute-Force": (
            "Uses Gobuster with the SecLists raft-small-directories wordlist to discover "
            "common subfolders, then fetches each and scans them with TruffleHog."
        )
    }
    page_mode = st.radio("Choose Scan Type:", list(page_type_descriptions.keys()), key="page_mode")
    st.markdown(f"**How this works:** {page_type_descriptions[page_mode]}")

    # ────────── Single Page ──────────
    if page_mode == "Single Page":
        url = st.text_input("Enter Website URL:", "https://example.com")
        if st.button("Scan Website"):
            ts = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_path = f"/home/kasm-user/Desktop/Downloads/trufflehog_single_{ts}.jsonl"
            with st.spinner("Scanning single page..."):
                resp = requests.get(url, timeout=10); resp.raise_for_status()
                tmp = tempfile.NamedTemporaryFile(delete=False, suffix='.html')
                tmp.write(resp.text.encode()); tmp.flush()
                cmd = [
                    "trufflehog", "filesystem", tmp.name,
                    "--results=verified,unknown", "--json", "--no-update"
                ]
                records = run_trufflehog(cmd, output_path)

    # ────────── Crawl Entire Site ──────────
    elif page_mode == "Crawl Entire Site":
        raw_url = st.text_input("Enter any URL on the site to crawl:", "https://example.com/path")
        max_pages = st.number_input("Max pages to crawl:", 1, 100, 10)
        scope = st.selectbox("Crawl Scope:", ["Root Domain", "Exact Host"], key="crawl_scope")
        scope_desc = {
            "Root Domain": "Follows links whose registered domain matches the site’s root (includes subdomains).",
            "Exact Host": "Follows links whose host exactly matches the start URL (no subdomains)."
        }
        st.markdown(f"**Scope explanation:** {scope_desc[scope]}")
        if st.button("Crawl and Scan"):
            ts = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_path = f"/home/kasm-user/Desktop/Downloads/trufflehog_crawl_{ts}.jsonl"
            with st.spinner(f"Crawling up to {max_pages} pages ({scope})..."):
                parsed = urlparse(raw_url)
                start_site = f"{parsed.scheme}://{parsed.netloc}"
                records = crawl_and_scan(start_site, max_pages, scope, output_path)

    # ────────── Directory Brute-Force ──────────
    else:
        base_url = st.text_input("Enter base URL (e.g. https://example.com):", "https://example.com")
        threads = st.number_input("Gobuster threads:", 10, 100, 50)
        if st.button("Scan Directories"):
            ts = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_path = f"/home/kasm-user/Desktop/Downloads/trufflehog_dirbf_{ts}.jsonl"
            gobuster_log_path = os.path.join(
                os.path.dirname(output_path),
                f"gobuster_dirbf_{ts}.txt"
            )
            os.makedirs(os.path.dirname(output_path), exist_ok=True)

            # Download wordlist
            with st.spinner("Downloading wordlist..."):
                wl_url = (
                    "https://raw.githubusercontent.com/danielmiessler/"
                    "SecLists/master/Discovery/Web-Content/raft-small-directories.txt"
                )
                wl_resp = requests.get(wl_url); wl_resp.raise_for_status()
                tmp_wl = tempfile.NamedTemporaryFile(delete=False, suffix=".txt")
                tmp_wl.write(wl_resp.content); tmp_wl.flush()

            # Run Gobuster with -q, disable blacklist, and -o
            with st.spinner("Running Gobuster..."):
                cmd = [
                    "gobuster", "dir",
                    "-u", base_url,
                    "-w", tmp_wl.name,
                    "-t", str(threads),
                    "-e",
                    "-s", "200,204,301,302,307,401,403",
                    "-b", "",
                    "-q",
                    "-o", gobuster_log_path
                ]
                st.text(f"🔍 Running command: {' '.join(cmd)}")
                subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                st.text(f"📄 Gobuster log saved to: {gobuster_log_path}")

            # Parse found URLs
            found_paths = []
            with open(gobuster_log_path) as gf:
                for line in gf:
                    line = line.strip()
                    if not line or line.startswith("===="):
                        continue
                    url_candidate = line.split()[0]
                    found_paths.append(url_candidate)
            st.success(f"Found {len(found_paths)} paths")

            # Fetch each and scan
            records = []
            for full_url in found_paths:
                try:
                    resp = requests.get(full_url, timeout=10); resp.raise_for_status()
                    tmp_html = tempfile.NamedTemporaryFile(delete=False, suffix='.html')
                    tmp_html.write(resp.text.encode()); tmp_html.flush()
                    records.extend(run_trufflehog(
                        ["trufflehog", "filesystem", tmp_html.name,
                         "--results=verified,unknown", "--json", "--no-update"],
                        output_path
                    ))
                except Exception as e:
                    st.warning(f"Failed to fetch {full_url}: {e}")

elif scan_mode == "Git Repository Scan":
    repo = st.text_input("Enter Git Repo URL:", "https://github.com/user/repo.git")
    if st.button("Scan Repository"):
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_path = f"/home/kasm-user/Desktop/Downloads/trufflehog_gitrepo_{ts}.jsonl"
        with st.spinner("Scanning repository..."):
            cmd = ["trufflehog", "git", repo, "--results=verified,unknown", "--json", "--no-update"]
            records = run_trufflehog(cmd, output_path)

elif scan_mode == "Local Git Repo Scan":
    path = st.text_input("Enter Local Path:", "file://./repo")
    if st.button("Scan Local Repo"):
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_path = f"/home/kasm-user/Desktop/Downloads/trufflehog_localgit_{ts}.jsonl"
        with st.spinner("Scanning local repo..."):
            cmd = ["trufflehog", "git", path, "--results=verified,unknown", "--json", "--no-update"]
            records = run_trufflehog(cmd, output_path)

elif scan_mode == "GitHub Org Scan":
    org = st.text_input("Enter GitHub Org:", "trufflesecurity")
    if st.button("Scan Org"):
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_path = f"/home/kasm-user/Desktop/Downloads/trufflehog_githuborg_{ts}.jsonl"
        with st.spinner("Scanning org..."):
            cmd = ["trufflehog", "github", "--org", org, "--results=verified,unknown", "--json", "--no-update"]
            records = run_trufflehog(cmd, output_path)

elif scan_mode == "GitHub Repo + Issues/PR Scan":
    repo = st.text_input("Enter GitHub Repo URL:", "https://github.com/user/repo.git")
    if st.button("Scan Issues/PRs"):
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_path = f"/home/kasm-user/Desktop/Downloads/trufflehog_ghissues_{ts}.jsonl"
        with st.spinner("Scanning issue/PR comments..."):
            cmd = [
                "trufflehog", "github", "--repo", repo,
                "--issue-comments", "--pr-comments",
                "--results=verified,unknown", "--json", "--no-update"
            ]
            records = run_trufflehog(cmd, output_path)

elif scan_mode == "GitHub Experimental Scan":
    repo = st.text_input("Enter Repo URL:", "https://github.com/user/repo.git")
    if st.button("Run Experimental Scan"):
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_path = f"/home/kasm-user/Desktop/Downloads/trufflehog_ghexp_{ts}.jsonl"
        with st.spinner("Running experimental scan..."):
            cmd = [
                "trufflehog", "github-experimental", "--repo", repo,
                "--object-discovery", "--delete-cached-data",
                "--results=verified,unknown", "--json", "--no-update"
            ]
            records = run_trufflehog(cmd, output_path)

elif scan_mode == "S3 Bucket Scan":
    bucket = st.text_input("Enter S3 Bucket:", "my-bucket")
    if st.button("Scan S3 Bucket"):
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_path = f"/home/kasm-user/Desktop/Downloads/trufflehog_s3_{ts}.jsonl"
        with st.spinner("Scanning S3 bucket..."):
            cmd = ["trufflehog", "s3", "--bucket", bucket, "--results=verified,unknown", "--json", "--no-update"]
            records = run_trufflehog(cmd, output_path)

elif scan_mode == "S3 Bucket with IAM Role":
    role = st.text_input("Enter IAM Role ARN:", "arn:aws:iam::123456789012:role/MyRole")
    if st.button("Scan S3 with Role"):
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_path = f"/home/kasm-user/Desktop/Downloads/trufflehog_s3role_{ts}.jsonl"
        with st.spinner("Scanning S3 with IAM role..."):
            cmd = ["trufflehog", "s3", "--role-arn", role, "--results=verified,unknown", "--json", "--no-update"]
            records = run_trufflehog(cmd, output_path)

elif scan_mode == "GCS Bucket Scan":
    pid = st.text_input("Enter GCP Project ID:", "my-project")
    if st.button("Scan GCS Bucket"):
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_path = f"/home/kasm-user/Desktop/Downloads/trufflehog_gcs_{ts}.jsonl"
        with st.spinner("Scanning GCS bucket..."):
            cmd = ["trufflehog", "gcs", "--project-id", pid, "--cloud-environment", "--results=verified,unknown", "--json", "--no-update"]
            records = run_trufflehog(cmd, output_path)

elif scan_mode == "SSH Git Repo Scan":
    ssh_url = st.text_input("Enter SSH Git URL:", "git@github.com:user/repo.git")
    if st.button("Scan SSH Repo"):
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_path = f"/home/kasm-user/Desktop/Downloads/trufflehog_ssh_{ts}.jsonl"
        with st.spinner("Scanning SSH repo..."):
            cmd = ["trufflehog", "git", ssh_url, "--results=verified,unknown", "--json", "--no-update"]
            records = run_trufflehog(cmd, output_path)

elif scan_mode == "Filesystem Scan":
    paths = st.text_input("Enter paths comma-separated:", "/file1.txt,/dir")
    if st.button("Scan Filesystem"):
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_path = f"/home/kasm-user/Desktop/Downloads/trufflehog_fs_{ts}.jsonl"
        with st.spinner("Scanning filesystem..."):
            items = [p.strip() for p in paths.split(",")]
            cmd = ["trufflehog", "filesystem"] + items + ["--results=verified,unknown", "--json", "--no-update"]
            records = run_trufflehog(cmd, output_path)

elif scan_mode == "Postman Workspace Scan":
    token = st.text_input("Postman API Token:", "")
    ws = st.text_input("Workspace ID:", "")
    coll = st.text_input("Collection ID:", "")
    if st.button("Scan Postman Workspace"):
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_path = f"/home/kasm-user/Desktop/Downloads/trufflehog_postman_{ts}.jsonl"
        with st.spinner("Scanning Postman workspace..."):
            cmd = ["trufflehog", "postman", "--token", token, "--workspace-id", ws, "--collection-id", coll, "--results=verified,unknown", "--json", "--no-update"]
            records = run_trufflehog(cmd, output_path)

elif scan_mode == "Jenkins Scan":
    url = st.text_input("Jenkins URL:", "https://jenkins.example.com")
    user = st.text_input("Username:", "admin")
    pwd = st.text_input("Password:", "", type="password")
    if st.button("Scan Jenkins Server"):
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_path = f"/home/kasm-user/Desktop/Downloads/trufflehog_jenkins_{ts}.jsonl"
        with st.spinner("Scanning Jenkins server..."):
            cmd = ["trufflehog", "jenkins", "--url", url, "--username", user, "--password", pwd, "--results=verified,unknown", "--json", "--no-update"]
            records = run_trufflehog(cmd, output_path)

elif scan_mode == "ElasticSearch Scan":
    nodes = st.text_input("Elasticsearch nodes comma-separated:", "127.0.0.1:9200")
    auth_type = st.selectbox("Auth type:", ["username_password", "service_token", "cloud_id_api_key"])
    args = ["trufflehog", "elasticsearch"] + nodes.split(",")
    if auth_type == "username_password":
        u = st.text_input("User:", "")
        p = st.text_input("Password:", "", type="password")
        args += ["--username", u, "--password", p]
    elif auth_type == "service_token":
        tkn = st.text_input("Service token:", "")
        args += ["--service-token", tkn]
    else:
        cid = st.text_input("Cloud ID:", "")
        ak = st.text_input("API Key:", "")
        args += ["--cloud-id", cid, "--api-key", ak]
    if st.button("Scan Elasticsearch"):
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_path = f"/home/kasm-user/Desktop/Downloads/trufflehog_es_{ts}.jsonl"
        records = run_trufflehog(args + ["--results=verified,unknown", "--json", "--no-update"], output_path)

elif scan_mode == "HuggingFace Scan":
    model = st.text_input("Model ID:", "")
    space = st.text_input("Space ID:", "")
    dset = st.text_input("Dataset ID:", "")
    org = st.text_input("Organization/User:", "")
    incl = st.checkbox("Include discussions/PRs")
    if st.button("Scan HuggingFace"):
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_path = f"/home/kasm-user/Desktop/Downloads/trufflehog_hf_{ts}.jsonl"
        args = ["trufflehog", "huggingface"]
        if model: args += ["--model", model]
        if space: args += ["--space", space]
        if dset: args += ["--dataset", dset]
        if org: args += ["--org", org]
        if incl: args += ["--include-discussions", "--include-prs"]
        records = run_trufflehog(args + ["--results=verified,unknown", "--json", "--no-update"], output_path)

# Display results
if records is not None:
    if not records:
        st.success("✅ No secrets found.")
    else:
        st.subheader("Summary of Results")
        rows = [{
            'SourceName': r.get('SourceName',''),
            'DetectorName': r.get('DetectorName',''),
            'Verified': r.get('Verified',''),
            'Raw': (r.get('Raw','')[:20] + '...') if r.get('Raw') else ''
        } for r in records]
        df = pd.DataFrame(rows)
        st.dataframe(df, use_container_width=True)

        st.subheader("Detailed Records")
        for i, r in enumerate(records):
            with st.expander(f"Record {i+1}: {r.get('DetectorName','Unknown')}"):
                st.json(r)

        data_json = json.dumps(records, indent=2)
        st.download_button("Download JSON", data_json, "results.json", "application/json")
        csv_data = df.to_csv(index=False)
        st.download_button("Download CSV", csv_data, "summary.csv", "text/csv")
