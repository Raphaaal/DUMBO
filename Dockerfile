# Use Ubuntu 22.04 as base image
FROM ubuntu:22.04

# Set environment variable to avoid prompts during installations
ENV DEBIAN_FRONTEND=noninteractive

# Install Python 3.9 oustide of any conda environment
RUN apt-get update && \
    apt-get install gnupg -y && \
    apt-get install -y --no-install-recommends software-properties-common && \
    add-apt-repository ppa:deadsnakes/ppa

# Update package lists and install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    wireshark-common \
    python3.9 \
    libpython3.9-dev \
    python3.9-dev \
    python3.9-venv \
    build-essential \
    wget \
    curl \
    ca-certificates \
    git

# Create base Python 3.9 environment outside of conda
RUN python3.9 -m venv /venv
ENV PATH=/venv/bin:$PATH

# Install Rust v1.76.0-nightly
RUN curl https://sh.rustup.rs -sSf | sh -s -- --default-toolchain nightly-2024-02-08 -y
ENV PATH="/root/.cargo/bin:$PATH"

# COpy repository files (including traffice traces) and set working directory
COPY . /DUMBO
WORKDIR /DUMBO

# Build the repository
RUN cargo build -r

# Clone and patch the YAPS simulator repository
RUN git clone -n https://github.com/NetSys/simulator.git && \
    cd simulator && \
    git checkout -b scheduling_DUMBO 179b64e && \
    git apply < ../scheduling_DUMBO.patch && \
    cd ..

# Install Miniconda on x86 or ARM platforms
ENV PATH="/root/miniconda3/bin:$PATH"
ARG PATH="/root/miniconda3/bin:$PATH"
RUN arch=$(uname -m) && \
    if [ "$arch" = "x86_64" ]; then \
    MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-py39_23.9.0-0-Linux-x86_64.sh"; \
    elif [ "$arch" = "aarch64" ]; then \
    MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-py39_23.9.0-0-Linux-aarch64.sh"; \
    else \
    echo "Unsupported architecture: $arch"; \
    exit 1; \
    fi && \
    wget $MINICONDA_URL -O miniconda.sh && \
    mkdir -p /root/.conda && \
    bash miniconda.sh -b -p /root/miniconda3 && \
    rm -f miniconda.sh
ENV PATH="/opt/conda/bin:$PATH"

# Use Python 3.9 outside any conda env as default Python
ENV PATH=/venv/bin:$PATH

# Run setup_conda.sh
RUN chmod +x ./setup_conda.sh && \
    ./setup_conda.sh
RUN conda init
SHELL ["/bin/bash", "-c"]
RUN source ~/.bashrc

# Set default command
CMD ["/bin/bash"]