# ==============================================================================
# Ansible Control Image
# ==============================================================================
# Purpose:
#   This image is used by Jenkins to run Ansible Playbooks in an on-prem,
#   restricted / air-gapped environment.
#
# Important:
#   - This image contains tools only.
#   - Do NOT store credentials, SSH keys, Vault passwords, tokens, or domain users.
#   - Jenkins should inject secrets at runtime using Jenkins Credentials.
#
# Main use cases:
#   - Configure Linux servers over SSH.
#   - Configure Windows servers over WinRM.
#   - Interact with VMware vCenter / vSphere.
#   - Call vRA / Aria Automation APIs.
#   - Download installers/packages from Artifactory.
#   - Run ansible-lint and syntax checks before execution.
# ==============================================================================

# Use only approved internal base images in on-prem environments.
# Prefer UBI/Rocky/RHEL-based images if your enterprise Linux standard is RHEL-like.
FROM registry.redhat.io/ubi9/ubi:latest

# Metadata helps with auditability in internal registries like Artifactory.
LABEL maintainer="DevOps Team"
LABEL image.type="ansible-control"
LABEL image.purpose="jenkins-ansible-onprem-automation"

# Pin Ansible version.
# Do not use latest. Reproducibility is critical in isolated environments.
ARG ANSIBLE_CORE_VERSION=2.18.6

# Use root only during build because we need to install OS packages.
USER root

# ==============================================================================
# Copy configuration and dependency files
# ==============================================================================

# pip.conf points pip to internal Artifactory/PyPI mirror.
COPY config/pip.conf /etc/pip.conf

# ansible.cfg defines default Ansible behavior inside Jenkins jobs.
COPY config/ansible.cfg /etc/ansible/ansible.cfg

# OS packages needed by the control node.
COPY requirements/rpm-packages.txt /tmp/rpm-packages.txt

# Python packages needed by Ansible modules/plugins and helper scripts.
COPY requirements/requirements.txt /tmp/requirements.txt

# Ansible Collections: Windows, VMware, Linux, utilities, etc.
COPY requirements/requirements.yml /tmp/requirements.yml

# ==============================================================================
# Install OS packages
# ==============================================================================

# Install packages required by:
#   - SSH to Linux targets
#   - WinRM/Kerberos to Windows targets
#   - Python packages that require compilation
#   - Debugging Jenkins/Ansible runs
#   - Downloading artifacts from Artifactory
RUN dnf install -y $(cat /tmp/rpm-packages.txt) \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# ==============================================================================
# Install Python dependencies
# ==============================================================================

# Upgrade pip tooling from your internal PyPI mirror.
# All packages should come from Artifactory because this image may be built for
# restricted/air-gapped usage.
RUN python3 -m pip install --upgrade pip setuptools wheel

# Install ansible-core explicitly.
# ansible-core gives us the core engine without blindly pulling the full "ansible"
# community bundle.
RUN python3 -m pip install "ansible-core==${ANSIBLE_CORE_VERSION}"

# Install Python libraries needed for Windows, VMware, APIs, crypto, parsing, etc.
RUN python3 -m pip install -r /tmp/requirements.txt

# ==============================================================================
# Install Ansible Collections
# ==============================================================================

# Collections are installed into a global path inside the image.
# This lets Jenkins run playbooks without downloading collections during the job.
#
# Ansible supports installing multiple collections from requirements.yml.
RUN ansible-galaxy collection install \
      -r /tmp/requirements.yml \
      -p /usr/share/ansible/collections

# ==============================================================================
# Create runtime directories
# ==============================================================================

# /work:
#   Jenkins workspace will usually be mounted here.
#
# /tmp/ansible_fact_cache:
#   Used by ansible.cfg for fact caching.
#
# /tmp/.ansible/cp:
#   Used by SSH ControlPersist sockets.
RUN mkdir -p \
      /work \
      /tmp/ansible_fact_cache \
      /tmp/.ansible/cp \
      /home/ansible/.ansible/tmp

# Create a non-root runtime user.
# Jenkins can also override this with docker -u UID:GID if needed.
RUN useradd -u 1000 -m -s /bin/bash ansible || true \
    && chown -R ansible:ansible \
       /work \
       /tmp/ansible_fact_cache \
       /tmp/.ansible \
       /home/ansible

# ==============================================================================
# Runtime environment
# ==============================================================================

# Force Ansible to use the config baked into the image unless Jenkins overrides it.
ENV ANSIBLE_CONFIG=/etc/ansible/ansible.cfg

# Keep colorized output in Jenkins logs.
ENV ANSIBLE_FORCE_COLOR=true

# Avoid Python buffering so logs are visible immediately in Jenkins.
ENV PYTHONUNBUFFERED=1

# Avoid writing pyc files in mounted Jenkins workspace.
ENV PYTHONDONTWRITEBYTECODE=1

# Use non-root user by default.
USER ansible

# Jenkins will usually mount the automation repo here.
WORKDIR /work

# Default command for quick smoke test.
CMD ["ansible", "--version"]
