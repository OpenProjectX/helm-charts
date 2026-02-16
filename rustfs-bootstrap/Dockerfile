FROM python:3.14.2-bookworm

# Install minimal runtime deps
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
 && rm -rf /var/lib/apt/lists/*

# Install rc CLI
# Adjust URL if you pin a specific version
RUN curl -fsSL https://github.com/rustfs/cli/releases/download/v0.1.3/rustfs-cli-linux-amd64-v0.1.3.tar.gz \
        -o /tmp/rustfs-cli.tar.gz \
 && tar -xzf /tmp/rustfs-cli.tar.gz -C /tmp \
 && mv /tmp/rc /usr/local/bin/rc \
 && chmod +x /usr/local/bin/rc \
 && rm -f /tmp/rustfs-cli.tar.gz

# Install Python deps
RUN pip install --no-cache-dir pyyaml

# Create app directory
WORKDIR /app

# Copy bootstrap script
COPY bootstrap.py /app/bootstrap.py

# Ensure executable
RUN chmod +x /app/bootstrap.py

ENTRYPOINT ["python", "/app/bootstrap.py"]
