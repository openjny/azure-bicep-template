# https://github.com/nektos/act#runners
FROM ghcr.io/catthehacker/ubuntu:act-latest

# Install Azure CLI
RUN apt-get update \
    && curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash \
    && rm -rf /var/lib/apt/lists/*

# Install bicep
RUN az bicep install