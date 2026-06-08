# Ansible Control Image

An enterprise-grade Ansible control node Docker image designed for on-premises, restricted, and air-gapped environments. This image contains all necessary tools for managing Linux, Windows, and VMware infrastructure with Jenkins integration.

## Overview

This repository provides:

- **Dockerfile**: Comprehensive Ansible control image with Windows, VMware, and Linux support
- **Configuration files**: Pre-tuned Ansible, pip, and environment settings
- **Dependency management**: Pinned versions for Python packages and Ansible Collections
- **Jenkins integration**: Ready for containerized automation workflows
- **Build scripts**: Setup, validation, and quality assurance tools

### Key Features

✅ **Linux Management**: SSH, POSIX modules, community roles  
✅ **Windows Support**: WinRM, Kerberos, CredSSP authentication  
✅ **VMware Integration**: vCenter/vSphere automation via community.vmware  
✅ **API Automation**: REST client, JSON/YAML parsing, Artifactory support  
✅ **Quality Tools**: ansible-lint, yamllint, syntax validation  
✅ **Secure**: No credentials/secrets embedded; ready for Jenkins secret injection  
✅ **Reproducible**: Pinned versions, offline-capable, immutable build  

## Quick Start

### Build the Image

```bash
# Clone this repository
git clone https://github.com/devopsteamelt/ansible.git
cd ansible

# Build the image
./scripts/build.sh 1.0.0
```

### Use the Image with Docker

```bash
# Run a simple Ansible check
docker run --rm \
  -v $(pwd):/work \
  -e ANSIBLE_CONFIG=/etc/ansible/ansible.cfg \
  registry.local/devops/ansible-control:1.0.0 \
  ansible --version

# Run with SSH key for target access
docker run --rm \
  -v $(pwd):/work \
  -v ~/.ssh/id_rsa:/home/ansible/.ssh/id_rsa:ro \
  -e ANSIBLE_CONFIG=/etc/ansible/ansible.cfg \
  registry.local/devops/ansible-control:1.0.0 \
  ansible-playbook -i inventories/dev/hosts.yml playbooks/site.yml
```

### Run Tests

```bash
# Validate the image contains all expected tools
./scripts/test-image.sh registry.local/devops/ansible-control:1.0.0

# Or manually inspect
docker run --rm registry.local/devops/ansible-control:1.0.0 ansible-galaxy collection list
docker run --rm registry.local/devops/ansible-control:1.0.0 python3 -m pip list
```

## Repository Structure

```
ansible-control/
├── Dockerfile                          # Main image definition
├── README.md                           # This file
├── requirements/
│   ├── requirements.txt               # Python/PIP packages
│   ├── requirements.yml               # Ansible Collections
│   └── rpm-packages.txt               # OS/system packages
├── config/
│   ├── ansible.cfg                    # Global Ansible behavior
│   └── pip.conf                       # Artifactory PyPI config
└── scripts/
    ├── build.sh                       # Build image
    └── test-image.sh                  # Validate image
```

## Configuration Files

### Dockerfile

The main image definition includes:
- **Base image**: UBI 9 with Python 3.11 (change to your approved internal base)
- **OS packages**: SSH, WinRM, Kerberos, debugging tools, certificate support
- **Python packages**: Ansible-core, Windows/VMware/API libraries, quality tools
- **Collections**: Pinned Ansible Collections for Linux, Windows, VMware, networking
- **User**: Non-root `ansible` user for Jenkins execution
- **Environment**: Pre-configured for offline/restricted environments

### requirements.yml

Ansible Collections installed during image build:

- `ansible.posix` - Linux/POSIX modules
- `ansible.windows` - Windows management
- `community.general` - Broad utility modules
- `community.windows` - Additional Windows modules
- `community.vmware` - VMware/vCenter automation
- `vmware.vmware_rest` - VMware REST API integration
- `community.crypto` - SSL/TLS/certificate management
- `community.docker` - Container image operations
- And more (see `requirements/requirements.yml` for complete list)

### requirements.txt

Python packages for:
- Windows/WinRM: `pywinrm`, `pykerberos`, `requests-kerberos`, `requests-credssp`
- VMware: `pyvmomi`, `vmware-rest-client`
- APIs: `requests`, `tenacity`, `urllib3`
- Parsing: `pyyaml`, `jmespath`, `jsonschema`, `lxml`
- Artifactory: `dohq-artifactory`
- Quality: `ansible-lint`, `yamllint`
- And more (see `requirements/requirements.txt` for complete list)

### rpm-packages.txt

System packages installed:
- Network tools: `curl`, `wget`, `jq`, `openssh-clients`, `git`
- Kerberos support: `krb5-workstation`, `krb5-devel`
- Development: `gcc`, `python3-devel`, `make`
- Archives: `tar`, `gzip`, `unzip`, `xz`
- Certificates: `ca-certificates`, `openssl`

### ansible.cfg

Pre-tuned Ansible configuration:
- SSH pipelining enabled for performance
- Fact caching for multi-run jobs
- Collections path set to `/usr/share/ansible/collections`
- Host key checking enabled (security)
- Default inventory path for Jenkins jobs
- Timeout and retry settings for on-prem environments

### pip.conf

Internal Artifactory PyPI configuration:
- Points all pip installs to your internal PyPI mirror
- No credentials embedded (use Jenkins/network policies)
- Trusted host and retry settings for reliability

## Security Considerations

### ✅ What's Included

- SSH keys and certificate validation tools
- Public CA certificates
- Ansible collections for secure operations
- Quality/linting tools
- Debugging utilities

### ❌ What's NOT Included

- SSH private keys
- Vault passwords or tokens
- Artifactory credentials
- vRA/API tokens
- Domain user credentials
- Production inventory secrets
- Application/license installers
- Customer certificates with private keys

**Why?** Credentials should be injected at runtime via Jenkins Credentials or environment variables, never baked into the image.

## Usage with Jenkins

### Jenkinsfile Example

```groovy
node('linux-docker-agent') {
    timestamps {
        ansiColor('xterm') {
            def imageName = 'registry.isolated.local/devops/ansible-control:1.0.0'

            stage('Checkout') {
                checkout scm
            }

            docker.image(imageName).inside('''
                -e ANSIBLE_CONFIG=/etc/ansible/ansible.cfg
                -e ANSIBLE_FORCE_COLOR=true
                -v ${WORKSPACE}:/work
                -w /work
            ''') {
                stage('Syntax Check') {
                    sh '''
                        ansible-playbook -i inventories/dev/hosts.yml \
                          playbooks/site.yml --syntax-check
                    '''
                }

                stage('Run Playbook') {
                    withCredentials([
                        sshUserPrivateKey(credentialsId: 'ansible-ssh-key',
                            keyFileVariable: 'SSH_KEY',
                            usernameVariable: 'SSH_USER')
                    ]) {
                        sh '''
                            chmod 600 "$SSH_KEY"
                            ansible-playbook -i inventories/dev/hosts.yml \
                              playbooks/site.yml \
                              --user "$SSH_USER" \
                              --private-key "$SSH_KEY"
                        '''
                    }
                }
            }
        }
    }
}
```

## Building and Testing

### Build the Image

```bash
# Build with specific version
./scripts/build.sh 1.0.0

# Build without cache (strict reproducibility)
docker build --no-cache -t registry.local/devops/ansible-control:1.0.0 .
```

### Test the Image

```bash
# Run smoke tests
./scripts/test-image.sh registry.local/devops/ansible-control:1.0.0

# Manual validation
docker run --rm registry.local/devops/ansible-control:1.0.0 ansible --version
docker run --rm registry.local/devops/ansible-control:1.0.0 ansible-galaxy collection list
docker run --rm registry.local/devops/ansible-control:1.0.0 python3 -m pip list | grep -E "pywinrm|pyvmomi|requests"
```

## Environment Variables

Inside the container, these are pre-configured:

```bash
ANSIBLE_CONFIG=/etc/ansible/ansible.cfg          # Config file location
ANSIBLE_FORCE_COLOR=true                         # Colorized output for logs
PYTHONUNBUFFERED=1                               # Immediate log visibility
PYTHONDONTWRITEBYTECODE=1                        # No .pyc files in workspace
```

Override in Docker run or Jenkins:

```bash
docker run -e ANSIBLE_VERBOSITY=2 -e ANSIBLE_DIFF_ALWAYS=true ...
```

## Target Capabilities

### Linux
- SSH key-based authentication
- POSIX/systemd modules
- Package management (DNF, YUM, APT)
- User/group management
- Firewall (firewalld, ufw)
- Service/process control

### Windows
- WinRM over HTTPS
- Kerberos domain authentication
- CredSSP for complex scenarios
- Desired State Configuration (DSC) integration
- Windows service/feature management
- Registry modifications
- Software installation (MSI, PowerShell)

### VMware
- vCenter/vSphere automation
- Virtual machine provisioning
- Snapshot management
- Cluster/host management
- vRA/Aria API integration
- ESXi configuration

### APIs & Infrastructure
- HTTP/REST clients (requests library)
- JSON/YAML parsing and filtering
- IP/CIDR calculations
- Certificate generation/validation
- Artifactory integration
- Vault integration (optional)

## Version Management

This image uses **pinned versions** for reproducibility:

- Ansible-core: 2.18.6
- Collections: versioned in `requirements.yml`
- Python packages: versioned in `requirements.txt`
- Base image: UBI 9 with Python 3.11

**Why?** In on-premises/restricted environments, reproducibility is critical. Floating `latest` tags can cause unexpected breakage.

## Troubleshooting

### Windows WinRM Connection Issues
- Ensure target has WinRM configured (HTTP or HTTPS)
- Check Kerberos/domain authentication in ansible.cfg
- For CredSSP, ensure both sides have TLS 1.2+
- Test with: `ansible windows_host -m win_ping`

### SSH/Linux Connection Issues
- Verify SSH key is readable (chmod 600)
- Check ansible.cfg has correct interpreter_python
- Test with: `ansible linux_host -m ping`
- Enable verbosity: `ansible-playbook -vvv ...`

### VMware Connection Issues
- Verify vCenter credentials in playbook (never hardcode!)
- Test API connectivity: `ansible localhost -m vmware_about_info`
- Check vmware.vmware_rest or community.vmware version compatibility

### Collection/Package Not Found
- Verify collection installed: `ansible-galaxy collection list`
- Verify Python package installed: `python3 -m pip list | grep package-name`
- Check image build logs for errors

### Slow Performance in Restricted Network
- Enable fact caching (configured in ansible.cfg)
- Use `gathering: smart` to cache facts across hosts
- Use connection multiplexing via SSH (configured in ansible.cfg)
- Consider building a local registry mirror

## Contributing

This image is maintained by the DevOps team. To suggest improvements:

1. Test locally: `docker build -t test .`
2. Validate with `scripts/test-image.sh test`
3. Document changes in PRs
4. Update version in `scripts/build.sh` and tags

## License

This repository contains configuration and tooling. See individual components for their licenses.

## Support

For issues or questions:
- Check Ansible documentation: https://docs.ansible.com/
- Review Jenkins Docker integration: https://www.jenkins.io/doc/book/installing-jenkins/docker/
- For Windows: https://docs.ansible.com/ansible/latest/os_guide/windows_winrm.html
- For VMware: https://docs.ansible.com/ansible/latest/collections/community/vmware/

---

**Last Updated**: June 2026  
**Maintainer**: DevOps Team  
**Status**: Production-ready
