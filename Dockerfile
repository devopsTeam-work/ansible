# Self-contained Ansible Execution Environment for disconnected runtime use.
# This pinned Ansible Community base already supplies Python, ansible-core, and
# ansible-runner, avoiding the generic Python image's duplicate bootstrap work.
ARG BASE_IMAGE=ghcr.io/ansible-community/community-ee-minimal:2.18.8-1
FROM ${BASE_IMAGE}

# Keep Ansible temporary data in writable locations for the non-root user.
ENV ANSIBLE_CONFIG=/etc/ansible/ansible.cfg \
    ANSIBLE_HOME=/home/ansible/.ansible \
    ANSIBLE_LOCAL_TEMP=/tmp/ansible-local \
    ANSIBLE_REMOTE_TEMP=/tmp/ansible-remote \
    ANSIBLE_FORCE_COLOR=true \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

COPY requirements/galaxy.yml /tmp/galaxy.yml
COPY config/ansible.cfg /etc/ansible/ansible.cfg

# Install only controller tools needed for SSH, Kerberos, SMB, Git, and file
# transfer. Python packages are intentionally not installed in this image.
USER root
RUN dnf install -y --setopt=install_weak_deps=False \
       ca-certificates git krb5-workstation openssh-clients rsync samba-client sshpass \
    && ansible-galaxy collection install -r /tmp/galaxy.yml -p /usr/share/ansible/collections \
    && (id ansible >/dev/null 2>&1 || useradd --create-home --uid 1001 --shell /bin/bash ansible) \
    && mkdir -p /work /tmp/ansible-local/cp /tmp/ansible-remote /home/ansible/.ssh \
    && touch /home/ansible/.ssh/known_hosts \
    && chown -R ansible:ansible /work /tmp/ansible-local /tmp/ansible-remote /home/ansible \
    && chmod 0700 /home/ansible/.ssh \
    && chmod 0600 /home/ansible/.ssh/known_hosts \
    && dnf clean all \
    && rm -rf /var/cache/dnf /root/.cache /tmp/galaxy.yml

# Mount inventories, roles, playbooks, and runtime credentials below /work.
# Running as a non-root user reduces the impact of a compromised playbook.
WORKDIR /work
USER ansible

# An interactive shell is convenient for on-prem troubleshooting; CI jobs can
# override this with ansible, ansible-playbook, or ansible-lint directly.
CMD ["bash"]
