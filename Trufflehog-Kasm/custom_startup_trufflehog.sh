#!/bin/bash
# Custom startup script for Streamlit-based TruffleHog Scanner in Kasm

# Wait for the Kasm desktop environment
/usr/bin/desktop_ready

echo "[*] Launching Streamlit app..."
cd /app
source /app/venv/bin/activate
# Start via Streamlit CLI so proper server context is created
streamlit run app.py --server.address 0.0.0.0 --server.port 5000 --server.headless true &

# Wait for Streamlit to respond
echo "[*] Waiting for Streamlit to become responsive..."
for i in {1..20}; do
    if curl -s http://localhost:5000 > /dev/null; then
        echo "[+] Streamlit is ready"
        break
    fi
    echo "[-] Still waiting... ($i)"
    sleep 1
done

echo "[*] Opening in Chrome..."
google-chrome --no-sandbox --disable-dev-shm-usage --start-maximized http://localhost:5000 &
