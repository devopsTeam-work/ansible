# Offline Ansible controller image

This repository builds a general-purpose Ansible controller for disconnected
on-prem environments. Internet or internal mirrors are needed **only while
building**. Python packages and Galaxy collections are baked into the image, so
the resulting image runs without internet access.

## Layout

```text
.
|-- Dockerfile
|-- config/ansible.cfg
|-- requirements/
|   |-- python.txt
|   `-- galaxy.yml
`-- playbooks/
```

## Build on a connected machine

```bash
docker build -t ansible-controller:2.18 .
docker run --rm ansible-controller:2.18 ansible --version
docker run --rm ansible-controller:2.18 ansible-galaxy collection list
```

If your company mirrors images, PyPI, Debian, or Galaxy, point the Docker daemon
and build environment at those mirrors. Change `BASE_IMAGE` when the public base
image is not allowed:

```bash
docker build --build-arg BASE_IMAGE=registry.local/python:3.12-slim-bookworm \
  -t registry.local/automation/ansible-controller:2.18 .
```

## Transfer into the disconnected environment

```bash
docker save ansible-controller:2.18 | gzip > ansible-controller-2.18.tar.gz
# copy the archive through your approved transfer process
gzip -dc ansible-controller-2.18.tar.gz | docker load
```

## Run playbooks

Linux/macOS host:

```bash
docker run --rm -it \
  -v "$PWD:/work" \
  -v "$HOME/.ssh:/home/ansible/.ssh:ro" \
  ansible-controller:2.18 \
  ansible-playbook -i inventories/dev.yml playbooks/site.yml
```

PowerShell on Windows:

```powershell
docker run --rm -it `
  -v "${PWD}:/work" `
  -v "${HOME}/.ssh:/home/ansible/.ssh:ro" `
  ansible-controller:2.18 `
  ansible-playbook -i inventories/dev.yml playbooks/site.yml
```

Mount inventories, playbooks, roles, SSH keys, Kerberos configuration, Vault
password files, and certificates at runtime. Never bake secrets into the image.
For an interactive shell, omit the command after the image name.

The included dependencies cover common Linux, Windows/WinRM, Active Directory,
networking, VMware, Docker/Podman, Kubernetes, Vault, PostgreSQL, MySQL, API, Git,
and Python automation. No finite image can support every third-party module; add
new pinned dependencies to the two requirement files and rebuild intentionally.

## GitHub Actions publishing

The workflow in `.github/workflows/docker-image.yml` publishes the image when a
tag matching `ansible_controller.v<major>.<minor>.<patch>` is pushed.

Configure these under **GitHub repository > Settings > Secrets and variables >
Actions**:

- Variable `DOCKERHUB_USERNAME`: Docker Hub account or organization name.
- Secret `DOCKERHUB_TOKEN`: a Docker Hub access token with permission to push.

Create and push a release tag:

```bash
git tag ansible_controller.v1.0.0
git push origin ansible_controller.v1.0.0
```

This publishes `DOCKERHUB_USERNAME/ansible-controller:v1.0.0`. The workflow does
not publish `latest`.
