import streamlit as st
import requests
import tempfile
import subprocess
import json
import pandas as pd
import tldextract
from urllib.parse import urljoin, urlparse
from bs4 import BeautifulSoup

# Page configuration
st.set_page_config(page_title="Trufflehog WebUI", layout="wide")

# Theme selection
theme = st.sidebar.selectbox("Theme:", ["Light", "Dark"], index=1)
if theme == "Dark":
    st.markdown(
        '''
        <style>
        [data-testid="stAppViewContainer"], [data-testid="stSidebar"], .css-18e3th9, .css-1d391kg {
            background-color: #0E1117 !important;
            color: #FAFAFA !important;
        }
        div.stButton > button {
            background-color: #333333 !important; color: #FAFAFA !important;
        }
        input[type="text"], textarea, select {
            background-color: #1E1E1E !important; color: #FAFAFA !important; border-color: #555555 !important;
        }
        ::placeholder { color: #888888 !important; }
        label, .stTextInput label { color: #FAFAFA !important; }
        div[role="option"] { background-color: #1E1E1E !important; color: #FAFAFA !important; }
        </style>
        ''', unsafe_allow_html=True
    )

# App title
st.title("🔍 Trufflehog WebUI")

# Sidebar: Scan mode selection
scan_mode = st.sidebar.selectbox(
    "Scan Mode:",
    [
        "Website Scan", "Git Repository Scan", "Local Git Repo Scan",
        "GitHub Org Scan", "GitHub Repo + Issues/PR Scan", "GitHub Experimental Scan",
        "S3 Bucket Scan", "S3 Bucket with IAM Role", "GCS Bucket Scan",
        "SSH Git Repo Scan", "Filesystem Scan", "Postman Workspace Scan",
        "Jenkins Scan", "ElasticSearch Scan", "HuggingFace Scan",
    ]
)

# Descriptions
desc = {
    "Website Scan": "Scan a web page (single) or crawl site via filesystem mode.",
    "Git Repository Scan": "Scan a remote Git repository.",
    "Local Git Repo Scan": "Scan a local Git repository via file:// URI.",
    "GitHub Org Scan": "Scan all repositories in a GitHub organization.",
    "GitHub Repo + Issues/PR Scan": "Scan a GitHub repository including issue and PR comments.",
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
st.sidebar.markdown(f"**Description:** {desc.get(scan_mode, '')}")

# Run TruffleHog subprocess
def run_trufflehog(cmd):
    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if proc.returncode != 0:
        st.error(f"TruffleHog error: {proc.stderr.strip()}")
        return []
    results = []
    for line in proc.stdout.splitlines():
        try:
            results.append(json.loads(line))
        except:
            continue
    return results

# Crawler helper with scope filter
def crawl_and_scan(start_url, max_pages, scope):
    seen = set()
    queue = [start_url]
    all_results = []
    parsed = urlparse(start_url)
    host = parsed.netloc.split(':')[0]
    reg = tldextract.extract(start_url).registered_domain
    while queue and len(seen) < max_pages:
        url = queue.pop(0)
        if url in seen:
            continue
        seen.add(url)
        try:
            resp = requests.get(url, timeout=5)
            resp.raise_for_status()
            soup = BeautifulSoup(resp.text, 'html.parser')
            for a in soup.find_all('a', href=True):
                link = urljoin(url, a['href'])
                netloc = urlparse(link).netloc.split(':')[0]
                if scope == "Root Domain":
                    if tldextract.extract(link).registered_domain != reg:
                        continue
                else:  # Exact Host
                    if netloc != host:
                        continue
                if link not in seen:
                    queue.append(link)
            tmp = tempfile.NamedTemporaryFile(delete=False, suffix='.html')
            tmp.write(resp.text.encode()); tmp.flush()
            cmd = ["trufflehog", "filesystem", tmp.name, "--results=verified,unknown", "--json", "--no-update"]
            all_results.extend(run_trufflehog(cmd))
        except Exception as e:
            st.warning(f"Failed {url}: {e}")
    return all_results

# Main logic
records = None
if scan_mode == "Website Scan":
    page_mode = st.radio("Choose Scan Type:", ["Single Page", "Crawl Entire Site"])
    if page_mode == "Single Page":
        url = st.text_input("Enter Website URL:", "https://example.com")
        if st.button("Scan Website"):
            with st.spinner("Scanning single page..."):
                resp = requests.get(url, timeout=10); resp.raise_for_status()
                tmp = tempfile.NamedTemporaryFile(delete=False, suffix='.html')
                tmp.write(resp.text.encode()); tmp.flush()
                cmd = ["trufflehog", "filesystem", tmp.name, "--results=verified,unknown", "--json", "--no-update"]
                records = run_trufflehog(cmd)
    else:
        start_url = st.text_input("Start URL for Crawl:", "https://example.com")
        max_pages = st.number_input("Max pages to crawl:", 1, 100, 10)
        scope = st.selectbox("Crawl Scope:", ["Root Domain", "Exact Host"])
        if st.button("Crawl and Scan"):
            with st.spinner(f"Crawling up to {max_pages} pages ({scope})..."):
                records = crawl_and_scan(start_url, max_pages, scope)

elif scan_mode == "Git Repository Scan":
    repo = st.text_input("Enter Git Repo URL:", "https://github.com/user/repo.git")
    if st.button("Scan Repository"):
        with st.spinner("Scanning repository..."):
            cmd = ["trufflehog", "git", repo, "--results=verified,unknown", "--json", "--no-update"]
            records = run_trufflehog(cmd)

elif scan_mode == "Local Git Repo Scan":
    path = st.text_input("Enter Local Path:", "file://./repo")
    if st.button("Scan Local Repo"):
        with st.spinner("Scanning local repo..."):
            cmd = ["trufflehog", "git", path, "--results=verified,unknown", "--json", "--no-update"]
            records = run_trufflehog(cmd)

elif scan_mode == "GitHub Org Scan":
    org = st.text_input("Enter GitHub Org:", "trufflesecurity")
    if st.button("Scan Org"):
        with st.spinner("Scanning org..."):
            cmd = ["trufflehog", "github", "--org", org, "--results=verified,unknown", "--json", "--no-update"]
            records = run_trufflehog(cmd)

elif scan_mode == "GitHub Repo + Issues/PR Scan":
    repo = st.text_input("Enter GitHub Repo URL:", "https://github.com/user/repo.git")
    if st.button("Scan Issues/PRs"):
        with st.spinner("Scanning issues/PRs..."):
            cmd = ["trufflehog", "github", "--repo", repo, "--issue-comments", "--pr-comments", "--results=verified,unknown", "--json", "--no-update"]
            records = run_trufflehog(cmd)

elif scan_mode == "GitHub Experimental Scan":
    repo = st.text_input("Enter Repo URL:", "https://github.com/user/repo.git")
    if st.button("Run Experimental Scan"):
        with st.spinner("Running experimental scan..."):
            cmd = ["trufflehog", "github-experimental", "--repo", repo, "--object-discovery", "--delete-cached-data", "--results=verified,unknown", "--json", "--no-update"]
            records = run_trufflehog(cmd)

elif scan_mode == "S3 Bucket Scan":
    bucket = st.text_input("Enter S3 Bucket:", "my-bucket")
    if st.button("Scan S3 Bucket"):
        with st.spinner("Scanning S3 bucket..."):
            cmd = ["trufflehog", "s3", "--bucket", bucket, "--results=verified,unknown", "--json", "--no-update"]
            records = run_trufflehog(cmd)

elif scan_mode == "S3 Bucket with IAM Role":
    role = st.text_input("Enter IAM Role ARN:", "arn:aws:iam::123456789012:role/MyRole")
    if st.button("Scan S3 with Role"):
        with st.spinner("Scanning S3 with IAM role..."):
            cmd = ["trufflehog", "s3", "--role-arn", role, "--results=verified,unknown", "--json", "--no-update"]
            records = run_trufflehog(cmd)

elif scan_mode == "GCS Bucket Scan":
    pid = st.text_input("Enter GCP Project ID:", "my-project")
    if st.button("Scan GCS Bucket"):
        with st.spinner("Scanning GCS bucket..."):
            cmd = ["trufflehog", "gcs", "--project-id", pid, "--cloud-environment", "--results=verified,unknown", "--json", "--no-update"]
            records = run_trufflehog(cmd)

elif scan_mode == "SSH Git Repo Scan":
    ssh_url = st.text_input("Enter SSH Git URL:", "git@github.com:user/repo.git")
    if st.button("Scan SSH Repo"):
        with st.spinner("Scanning SSH repo..."):
            cmd = ["trufflehog", "git", ssh_url, "--results=verified,unknown", "--json", "--no-update"]
            records = run_trufflehog(cmd)

elif scan_mode == "Filesystem Scan":
    paths = st.text_input("Enter paths comma-separated:", "/file1.txt,/dir")
    if st.button("Scan Filesystem"):
        with st.spinner("Scanning filesystem..."):
            items = [p.strip() for p in paths.split(",")]
            cmd = ["trufflehog", "filesystem"] + items + ["--results=verified,unknown", "--json", "--no-update"]
            records = run_trufflehog(cmd)

elif scan_mode == "Postman Workspace Scan":
    token = st.text_input("Postman API Token:", "")
    ws = st.text_input("Workspace ID:", "")
    coll = st.text_input("Collection ID:", "")
    if st.button("Scan Postman Workspace"):
        with st.spinner("Scanning Postman workspace..."):
            cmd = ["trufflehog", "postman", "--token", token, "--workspace-id", ws, "--collection-id", coll, "--results=verified,unknown", "--json", "--no-update"]
            records = run_trufflehog(cmd)

elif scan_mode == "Jenkins Scan":
    url = st.text_input("Jenkins URL:", "https://jenkins.example.com")
    user = st.text_input("Username:", "admin")
    pwd = st.text_input("Password:", "", type="password")
    if st.button("Scan Jenkins Server"):
        with st.spinner("Scanning Jenkins server..."):
            cmd = ["trufflehog", "jenkins", "--url", url, "--username", user, "--password", pwd, "--results=verified,unknown", "--json", "--no-update"]
            records = run_trufflehog(cmd)

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
        with st.spinner("Scanning Elasticsearch cluster..."):
            cmd = args + ["--results=verified,unknown", "--json", "--no-update"]
            records = run_trufflehog(cmd)

elif scan_mode == "HuggingFace Scan":
    model = st.text_input("Model ID:", "")
    space = st.text_input("Space ID:", "")
    dset = st.text_input("Dataset ID:", "")
    org = st.text_input("Organization/User:", "")
    incl = st.checkbox("Include discussions/PRs")
    if st.button("Scan HuggingFace"):
        with st.spinner("Scanning HuggingFace..."):
            args = ["trufflehog", "huggingface"]
            if model:
                args += ["--model", model]
            if space:
                args += ["--space", space]
            if dset:
                args += ["--dataset", dset]
            if org:
                args += ["--org", org]
            if incl:
                args += ["--include-discussions", "--include-prs"]
            cmd = args + ["--results=verified,unknown", "--json", "--no-update"]
            records = run_trufflehog(cmd)

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
