# Offline Ansible controller image

This repository builds a general-purpose Ansible Execution Environment for disconnected
on-prem environments. Internet or internal mirrors are needed **only while
building**. Galaxy collections are baked into the image, so the resulting image
runs without internet access. Additional Python packages are intentionally left
for a later installation layer.

## Layout

```text
.
|-- Dockerfile
|-- config/ansible.cfg
|-- requirements/galaxy.yml
`-- playbooks/
```

## Build on a connected machine

```bash
docker build -t ansible-controller:2.18.8 .
docker run --rm ansible-controller:2.18.8 ansible --version
docker run --rm ansible-controller:2.18.8 ansible-galaxy collection list
```

If your company mirrors images, PyPI, Debian, or Galaxy, point the Docker daemon
and build environment at those mirrors. Change `BASE_IMAGE` when the public base
image is not allowed:

```bash
docker build --build-arg BASE_IMAGE=registry.local/ansible/community-ee-minimal:2.18.8-1 \
  -t registry.local/automation/ansible-controller:2.18.8 .
```

## Transfer into the disconnected environment

```bash
docker save ansible-controller:2.18.8 | gzip > ansible-controller-2.18.8.tar.gz
# copy the archive through your approved transfer process
gzip -dc ansible-controller-2.18.8.tar.gz | docker load
```

## Run playbooks

Linux/macOS host:

```bash
docker run --rm -it \
  -v "$PWD:/work" \
  -v "$HOME/.ssh:/home/ansible/.ssh:ro" \
  ansible-controller:2.18.8 \
  ansible-playbook -i inventories/dev.yml playbooks/site.yml
```

PowerShell on Windows:

```powershell
docker run --rm -it `
  -v "${PWD}:/work" `
  -v "${HOME}/.ssh:/home/ansible/.ssh:ro" `
  ansible-controller:2.18.8 `
  ansible-playbook -i inventories/dev.yml playbooks/site.yml
```

Mount inventories, playbooks, roles, SSH keys, Kerberos configuration, Vault
password files, and certificates at runtime. Never bake secrets into the image.
For an interactive shell, omit the command after the image name.

The included collections cover common Linux, Windows, Active Directory,
networking, VMware, Docker/Podman, Kubernetes, Vault, PostgreSQL, and MySQL
automation. Controller-side Python dependencies required by those integrations
are not installed in this image and must be added in a later derived image.

## GitHub Actions publishing

The workflow in `.github/workflows/docker-image.yml` publishes the image when a
tag matching `ansible_controller.v<major>.<minor>.<patch>` is pushed.

Configure this under **GitHub repository > Settings > Secrets and variables >
Actions**:

- Secret `DOCKERHUB_TOKEN`: a Docker Hub access token with permission to push.

The non-sensitive Docker Hub namespace `devopsteamelt` is defined directly in
the workflow. Do not use the Docker Hub login email as an image namespace.

Create and push a release tag:

```bash
git tag ansible_controller.v1.0.0
git push origin ansible_controller.v1.0.0
```

This publishes `devopsteamelt/ansible-controller:v1.0.0`. The workflow does
not publish `latest`.
