import streamlit as st
import subprocess
import re

# Page setup
st.set_page_config(page_title="Sherlock WebUI", layout="wide")

# Logo
st.image(
    "https://raw.githubusercontent.com/DoubtfulTurnip/doubtfulturnip-kasm-registry/"
    "1.1/workspaces/Sherlock/sherlock.png",
    width=120
)
st.title("Sherlock WebUI")

# Theme selection
theme = st.sidebar.selectbox("Theme:", ["Light", "Dark"], index=1)
if theme == "Dark":
    st.markdown(
        """
        <style>
        /* Dark backgrounds */
        [data-testid="stAppViewContainer"], [data-testid="stSidebar"] {
            background-color: #0E1117 !important;
        }
        /* All text in main area and sidebar */
        [data-testid="stAppViewContainer"] *, [data-testid="stSidebar"] * {
            color: #FAFAFA !important;
        }
        /* Buttons */
        div.stButton > button {
            background-color: #333333 !important;
            color: #FAFAFA !important;
        }
        /* Inputs & textareas */
        input, textarea {
            background-color: #1E1E1E !important;
            color: #FAFAFA !important;
            border-color: #555555 !important;
        }
        ::placeholder {
            color: #888888 !important;
        }
        /* BaseWeb select (combobox) container */
        [data-baseweb="select"] > div:first-child {
            background-color: #333333 !important;
            color: #FAFAFA !important;
        }
        /* Dropdown panel */
        [data-baseweb="select"] [role="listbox"] {
            background-color: #1E1E1E !important;
        }
        /* Each option */
        [data-baseweb="select"] [role="option"] {
            background-color: #1E1E1E !important;
            color: #FAFAFA !important;
        }
        </style>
        """,
        unsafe_allow_html=True
    )

# Input
username = st.text_input("Username to search:")

# Sidebar options
st.sidebar.header("Options")
tor = st.sidebar.checkbox("Use Tor (--tor)")
unique_tor = st.sidebar.checkbox("Unique Tor (--unique-tor)")
csv_out = st.sidebar.checkbox("CSV output (--csv)")
xlsx_out = st.sidebar.checkbox("XLSX output (--xlsx)")
browse = st.sidebar.checkbox("Browse (--browse)")
no_color = st.sidebar.checkbox("No color (--no-color)")
nsfw = st.sidebar.checkbox("Include NSFW (--nsfw)")
loose = st.sidebar.checkbox("Loose search (wildcard . _ -)")
timeout = st.sidebar.number_input("Timeout (sec)", value=60, min_value=1)
proxy = st.sidebar.text_input("Proxy URL (e.g. socks5://)")
sites = st.sidebar.text_input("Sites (comma-separated)")

# Run Sherlock and stream output
if st.button("Search"):
    if not username:
        st.error("Enter a username to search.")
    else:
        output_area = st.empty()
        lines = []

        # Loose-mode wildcard
        if loose:
            pattern = re.sub(r"[._-]+", "{?}", username)
            usernames = [pattern]
        else:
            usernames = [username]

        # Build command
        cmd = ["sherlock"]
        for flag, opt in [
            (tor, "--tor"), (unique_tor, "--unique-tor"),
            (csv_out, "--csv"), (xlsx_out, "--xlsx"),
            (browse, "--browse"), (no_color, "--no-color"),
            (nsfw, "--nsfw")
        ]:
            if flag:
                cmd.append(opt)
        cmd += ["--timeout", str(timeout)]
        if proxy:
            cmd += ["--proxy", proxy]
        for site in [s.strip() for s in sites.split(",") if s.strip()]:
            cmd += ["--site", site]
        cmd += usernames

        # Launch and stream output
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1
        )
        for ln in proc.stdout:
            lines.append(ln.rstrip())
            output_area.text("\n".join(lines))

        proc.wait()
        if proc.returncode != 0:
            st.error(f"Sherlock exited with code {proc.returncode}")
        else:
            st.success("Sherlock completed successfully!")
