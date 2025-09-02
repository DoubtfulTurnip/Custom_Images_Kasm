FROM python:3.8-slim

WORKDIR /app

# Build deps for lxml, evtx, scipy
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc g++ make libffi-dev libssl-dev python3-dev \
    libxml2-dev libxslt1-dev zlib1g-dev rustc cargo && \
    rm -rf /var/lib/apt/lists/*

COPY . /app

# Patch setup.py python_requires
RUN sed -i "s/>=3\.8\.\*/>=3.8/" setup.py && \
    pip install --upgrade "pip<24.1" && \
    pip install --no-cache-dir .

CMD ["uvicorn", "epagneul.api.app:app", "--host", "0.0.0.0", "--port", "8000"]
