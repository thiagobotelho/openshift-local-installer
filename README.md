# OpenShift Local Installer

Automação da instalação do Red Hat OpenShift Local (anteriormente conhecido como CodeReady Containers - CRC) para ambientes de desenvolvimento e teste local, utilizando Linux com suporte a libvirt/KVM.

---

## 📌 Descrição

Este projeto tem como objetivo provisionar de forma **automatizada** um ambiente OpenShift Local completo, ideal para laboratórios, testes de workloads e validação de funcionalidades do OpenShift sem depender de ambientes em nuvem.

O script `install.sh` realiza:

- Instalação de dependências (libvirt, qemu, virt-install, etc.)
- Configuração do ambiente de virtualização
- Instalação do binário CRC
- Aplicação do pull secret
- Inicialização do cluster

---

## 📦 Requisitos

| Recurso        | Mínimo recomendado       |
|----------------|--------------------------|
| CPU            | 4 vCPUs                  |
| RAM            | 16 GB                    |
| Disco          | 40 GB SSD (livres)       |
| SO             | Fedora, RHEL, CentOS     |
| Virtualização  | `libvirt` com `kvm`      |

> ❗ O uso de **VirtualBox não é suportado**. Apenas libvirt + KVM.

---

## 📁 Estrutura do Projeto

```
openshift-local-installer/
├── install.sh                  # Script automatizado de instalação
├── config/
│   └── pull-secret             # local e ignorado pelo Git
├── bin/
│   └── crc                     # Binário CRC
├── .gitignore
└── README.md
```

---

## 🚀 Como usar

1. **Clone o repositório:**
   ```bash
   git clone https://github.com/thiagobotelho/openshift-local-installer.git
   cd openshift-local-installer
   ```

2. **Adicione o Instalador e o Pull Secret:**
   - Acesse: [https://console.redhat.com/openshift/install/local](https://console.redhat.com/openshift/install/local)
   - Clique em `Download - OpenShift Local (crc)`
   - Salve como: `bin/crc/crc-linux-amd64.tar.xz`
   - Clique em `Download - pull secret`
   - Salve como: `config/pull-secret`

3. **Torne o script executável e execute:**
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

Os recursos podem ser ajustados sem editar o script:

```bash
CRC_MEMORY=24576 CRC_CPUS=8 CRC_DISK_SIZE=200 ./install.sh
```

Bootstrap opcional do OpenShift GitOps:

```bash
CRC_MEMORY=32768 CRC_CPUS=8 ./install.sh --deploy-gitops
```

O App-of-Apps é mantido no repositório `argocd-gitops`. Em um CRC com pouca
memória, sincronize as aplicações gradualmente.

O pull secret nunca deve ser commitado. Se um segredo real for publicado,
revogue-o no console da Red Hat e remova-o também do histórico Git.

---

## 🧪 Acessando o cluster

Após instalação:

```bash
eval $(crc oc-env)
oc login -u kubeadmin https://api.crc.testing:6443
crc console
```

---

## 📋 Observações

- O cluster é provisionado como **Single Node OpenShift (SNO)**.
- A instalação padrão aloca 16 GB de RAM e 4 CPUs. Você pode alterar com:
  ```bash
  crc config set memory 12288
  crc config set cpus 6
  ```

---

## 🧼 Remover ambiente

Para excluir o cluster CRC e limpar o ambiente:

```bash
crc stop
crc delete
```

---

## 📘 Referências

- [Documentação oficial do OpenShift Local](https://www.redhat.com/en/blog/install-openshift-local)
- [OpenShift Local no Red Hat Console](https://console.redhat.com/openshift/create/local)
