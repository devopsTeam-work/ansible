ARG BASE_IMAGE=python:3.12-slim-bookworm
FROM ${BASE_IMAGE}

ARG ANSIBLE_CORE_VERSION=2.18.6

ENV DEBIAN_FRONTEND=noninteractive \
    ANSIBLE_CONFIG=/etc/ansible/ansible.cfg \
    ANSIBLE_HOME=/home/ansible/.ansible \
    ANSIBLE_LOCAL_TEMP=/tmp/ansible-local \
    ANSIBLE_REMOTE_TEMP=/tmp/ansible-remote \
    ANSIBLE_FORCE_COLOR=true \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

COPY requirements/python.txt /tmp/python.txt
COPY requirements/galaxy.yml /tmp/galaxy.yml
COPY config/ansible.cfg /etc/ansible/ansible.cfg

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       bash ca-certificates curl git git-lfs gnupg jq krb5-user openssh-client \
       rsync sshpass unzip vim-tiny \
    && python -m pip install --no-cache-dir --upgrade pip setuptools wheel \
    && python -m pip install --no-cache-dir "ansible-core==${ANSIBLE_CORE_VERSION}" -r /tmp/python.txt \
    && ansible-galaxy collection install -r /tmp/galaxy.yml -p /usr/share/ansible/collections \
    && useradd --create-home --uid 1000 --shell /bin/bash ansible \
    && mkdir -p /work /tmp/ansible-local/cp /tmp/ansible-remote /home/ansible/.ssh \
    && chown -R ansible:ansible /work /tmp/ansible-local /tmp/ansible-remote /home/ansible \
    && chmod 0700 /home/ansible/.ssh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /root/.cache /tmp/python.txt /tmp/galaxy.yml

WORKDIR /work
USER ansible

CMD ["bash"]
