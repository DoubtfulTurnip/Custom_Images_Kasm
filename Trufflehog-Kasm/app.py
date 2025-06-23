import streamlit as st
import requests
import tempfile
import subprocess
import json

# Page configuration
st.set_page_config(page_title="Secret Scanner+, expanded", layout="wide")
st.title("🔍 Secret Scanner+")

# Sidebar: Choose scan mode
scan_mode = st.sidebar.selectbox(
    "Select Scan Mode:",
    [
        "Website Scan",
        "Git Repository Scan",
        "GitHub Org Scan",
        "GitHub Repo + Issues/PR Scan",
        "S3 Bucket Scan",
        "S3 Bucket with IAM Role",
        "SSH Git Repo Scan",
        "Filesystem Files/Dirs Scan",
        "Local Git Repo Scan",
        "GCS Bucket Scan",
        "Postman Workspace Scan",
        "Jenkins Server Scan",
        "ElasticSearch Scan",
        "GitHub Experimental Scan",
        "HuggingFace Scan"
    ]
)

# Mode descriptions
descriptions = {
    "Website Scan": "Scan a single web page (filesystem mode).",
    "Git Repository Scan": "Scan a Git repo URL (git mode).",
    "GitHub Org Scan": "Scan all repos in a GitHub org (github mode).",
    "GitHub Repo + Issues/PR Scan": "Scan a GitHub repo including issue and PR comments (github mode).",
    "S3 Bucket Scan": "Scan an S3 bucket for verified secrets (s3 mode).",
    "S3 Bucket with IAM Role": "Scan S3 using an IAM role ARN (s3 mode).",
    "SSH Git Repo Scan": "Scan a Git repo over SSH (git mode).",
    "Filesystem Files/Dirs Scan": "Scan local files or directories (filesystem mode).",
    "Local Git Repo Scan": "Scan a local git repo via file:// URI (git mode).",
    "GCS Bucket Scan": "Scan a GCS bucket (gcs mode).",
    "Postman Workspace Scan": "Scan a Postman workspace or collection (postman mode).",
    "Jenkins Server Scan": "Scan a Jenkins server (jenkins mode).",
    "ElasticSearch Scan": "Scan an Elasticsearch cluster (elasticsearch mode).",
    "GitHub Experimental Scan": "Scan with object discovery (github-experimental mode).",
    "HuggingFace Scan": "Scan HuggingFace models/datasets/spaces (huggingface mode)."
}

st.sidebar.markdown(f"**Description:** {descriptions.get(scan_mode)}")

# Utility to run subprocess

def run_trufflehog(cmd_args):
    try:
        proc = subprocess.run(
            cmd_args,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
    except Exception as e:
        st.error(f"Failed to run TruffleHog: {e}")
        return None
    if proc.returncode != 0:
        st.error(f"TruffleHog error: {proc.stderr.strip()}")
        return None
    records = []
    for line in proc.stdout.splitlines():
        try:
            records.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return records

# Collect input and command
cmd = []
if scan_mode == "Website Scan":
    url = st.text_input("Website URL", "https://example.com")
    if st.button("Run Website Scan"):
        tmp = tempfile.NamedTemporaryFile(mode="w+", delete=False, suffix=".html")
        try:
            resp = requests.get(url, timeout=10); resp.raise_for_status()
            tmp.write(resp.text); tmp.flush()
            cmd = ["trufflehog","filesystem",tmp.name,"--results=verified,unknown","--json","--no-update"]
        except Exception as e:
            st.error(f"Fetch error: {e}")

elif scan_mode == "Git Repository Scan":
    repo = st.text_input("Git Repo URL", "https://github.com/user/repo.git")
    if st.button("Run Repo Scan"):
        cmd = ["trufflehog","git",repo,"--results=verified,unknown","--json","--no-update"]

elif scan_mode == "GitHub Org Scan":
    org = st.text_input("GitHub Org", "trufflesecurity")
    if st.button("Run Org Scan"):
        cmd = ["trufflehog","github","--org",org,"--results=verified,unknown","--json","--no-update"]

elif scan_mode == "GitHub Repo + Issues/PR Scan":
    repo = st.text_input("GitHub Repo URL", "https://github.com/user/repo.git")
    if st.button("Run Issues/PR Scan"):
        cmd = ["trufflehog","github","--repo",repo,"--issue-comments","--pr-comments","--results=verified,unknown","--json","--no-update"]

elif scan_mode == "S3 Bucket Scan":
    bucket = st.text_input("S3 Bucket Name", "my-bucket")
    if st.button("Run S3 Scan"):
        cmd = ["trufflehog","s3","--bucket",bucket,"--results=verified,unknown","--json","--no-update"]

elif scan_mode == "S3 Bucket with IAM Role":
    role = st.text_input("IAM Role ARN", "arn:aws:iam::123456789012:role/MyRole")
    if st.button("Run S3 Role Scan"):
        cmd = ["trufflehog","s3","--role-arn",role,"--results=verified,unknown","--json","--no-update"]

elif scan_mode == "SSH Git Repo Scan":
    ssh_url = st.text_input("SSH URL", "git@github.com:user/repo.git")
    if st.button("Run SSH Repo Scan"):
        cmd = ["trufflehog","git",ssh_url,"--results=verified,unknown","--json","--no-update"]

elif scan_mode == "Filesystem Files/Dirs Scan":
    paths = st.text_input("Paths (comma-separated)", "/path/to/file1.txt,/path/to/dir")
    if st.button("Run Filesystem Scan"):
        cmd = ["trufflehog","filesystem"] + [p.strip() for p in paths.split(",")] + ["--results=verified,unknown","--json","--no-update"]

elif scan_mode == "Local Git Repo Scan":
    local_path = st.text_input("Local Path", "file://./test_keys")
    if st.button("Run Local Git Scan"):
        cmd = ["trufflehog","git",local_path,"--results=verified,unknown","--json","--no-update"]

elif scan_mode == "GCS Bucket Scan":
    project = st.text_input("GCP Project ID", "my-project")
    if st.button("Run GCS Scan"):
        cmd = ["trufflehog","gcs","--project-id",project,"--cloud-environment","--results=verified,unknown","--json","--no-update"]

elif scan_mode == "Postman Workspace Scan":
    token = st.text_input("Postman API Token", "")
    workspace = st.text_input("Workspace ID", "")
    collection = st.text_input("Collection ID", "")
    if st.button("Run Postman Scan"):
        cmd = ["trufflehog","postman","--token",token,"--workspace-id",workspace,"--collection-id",collection,"--results=verified,unknown","--json","--no-update"]

elif scan_mode == "Jenkins Server Scan":
    url = st.text_input("Jenkins URL", "https://jenkins.example.com")
    user = st.text_input("Username", "admin")
    pwd = st.text_input("Password", "", type="password")
    if st.button("Run Jenkins Scan"):
        cmd = ["trufflehog","jenkins","--url",url,"--username",user,"--password",pwd,"--results=verified,unknown","--json","--no-update"]

elif scan_mode == "ElasticSearch Scan":
    nodes = st.text_input("Nodes (comma-separated)", "127.0.0.1:9200")
    auth_type = st.selectbox("Auth Type", ["username_password", "service_token", "cloud_id_api_key"])  
    if auth_type == "username_password":
        user = st.text_input("Username", "")
        pwd = st.text_input("Password", "", type="password")
    elif auth_type == "service_token":
        token = st.text_input("Service Token", "")
    else:
        cloud_id = st.text_input("Cloud ID", "")
        api_key = st.text_input("API Key", "")
    if st.button("Run ElasticScan"):
        args = ["trufflehog","elasticsearch"] + nodes.split(",")
        if auth_type == "username_password": args += ["--username",user,"--password",pwd]
        if auth_type == "service_token": args += ["--service-token",token]
        if auth_type == "cloud_id_api_key": args += ["--cloud-id",cloud_id,"--api-key",api_key]
        args += ["--results=verified,unknown","--json","--no-update"]
        cmd = args

elif scan_mode == "GitHub Experimental Scan":
    repo = st.text_input("Repo URL", "https://github.com/user/repo.git")
    if st.button("Run Experimental Scan"):
        cmd = ["trufflehog","github-experimental","--repo",repo,"--object-discovery","--delete-cached-data","--results=verified,unknown","--json","--no-update"]

else:  # HuggingFace Scan
    model = st.text_input("Model ID", "")
    space = st.text_input("Space ID", "")
    dataset = st.text_input("Dataset ID", "")
    org = st.text_input("Organization or User", "")
    include_disc = st.checkbox("Include Discussions/PRs")
    if st.button("Run HuggingFace Scan"):
        cmd = ["trufflehog","huggingface"]
        if model: cmd += ["--model",model]
        if space: cmd += ["--space",space]
        if dataset: cmd += ["--dataset",dataset]
        if org: cmd += ["--org",org]
        if include_disc: cmd += ["--include-discussions","--include-prs"]
        cmd += ["--results=verified,unknown","--json","--no-update"]

# Execute command if set
if cmd:
    records = run_trufflehog(cmd)
    if records is not None:
        if not records:
            st.success("✅ No secrets found.")
        else:
            st.subheader("Results")
            st.json(records)
            data_json = json.dumps(records, indent=2)
            st.download_button("Download JSON", data_json, "results.json","application/json")
            try:
                import pandas as pd
                df = pd.json_normalize(records)
                csv = df.to_csv(index=False)
                st.download_button("Download CSV", csv, "results.csv","text/csv")
            except Exception:
                pass
