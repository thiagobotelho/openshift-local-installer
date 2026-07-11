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
- Habilitação do monitoramento de plataforma do OpenShift Local

---

## 📦 Requisitos

| Recurso | Mínimo para CRC | Recomendado para a stack completa |
|---|---:|---:|
| CPU | 4 vCPUs | 10 vCPUs |
| RAM | 16 GiB | 40 GiB para o CRC |
| Disco | 40 GiB livres | 200 GiB para o disco do CRC |
| SO | Fedora, RHEL, CentOS | Fedora, RHEL, CentOS |
| Virtualização | `libvirt` com `kvm` | `libvirt` com `kvm` |

> ❗ O uso de **VirtualBox não é suportado**. Apenas libvirt + KVM.

---

## 📁 Estrutura do Projeto

```
openshift-local-installer/
├── install.sh                  # Script automatizado de instalação
├── config/
│   └── pull-secret             # local e ignorado pelo Git
├── bin/
│   └── crc/
│       └── README.md           # instruções para baixar o pacote CRC
├── .env.example                # variáveis do instalador/validador
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

3. **Revise as variáveis e execute:**
   ```bash
   cp -n .env.example .env
   chmod +x install.sh
   ./install.sh
   ```

O `install.sh` lê `.env` automaticamente. Também é possível sobrescrever
variáveis na chamada:

```bash
CRC_MEMORY=32768 CRC_CPUS=8 CRC_DISK_SIZE=200 ./install.sh
```

Bootstrap opcional do OpenShift GitOps:

```bash
CRC_MEMORY=40960 CRC_CPUS=10 ./install.sh --deploy-gitops
```

O bootstrap do OpenShift GitOps é aplicado em fases: primeiro `Namespace`,
`OperatorGroup` e `Subscription`, depois aguarda a CRD `argocds.argoproj.io` e
só então cria a instância `ArgoCD`. Isso evita o erro de primeira instalação
`no matches for kind "ArgoCD"`. O App-of-Apps é mantido no repositório
`argocd-gitops`. Em um CRC com pouca memória, sincronize as aplicações
gradualmente.

Para a stack completa de observabilidade local, habilite o monitoramento de
plataforma do OpenShift antes de iniciar/reiniciar o CRC. O `install.sh` já
aplica essa configuração, mas o comando manual é:

```bash
crc config set enable-cluster-monitoring true
crc config set memory 40960
crc config set cpus 10
crc stop
crc start
```

Mudanças de CPU/memória/monitoramento só entram em vigor após novo `crc start`.

### User Workload Monitoring

Nesta stack, o User Workload Monitoring nativo fica desativado por padrão. Os
workloads são coletados pelo repositório `prometheus-gitops`, usando
`MonitoringStack` do Cluster Observability Operator e os `ServiceMonitor`
`monitoring.rhobs/v1` com label `observability=platform`.

Se você já ativou o UWM anteriormente e quer economizar recursos no CRC:

```bash
scripts/disable-user-workload-monitoring.sh
```

Se quiser habilitar o UWM nativo para testes específicos:

```bash
scripts/enable-user-workload-monitoring.sh
oc -n openshift-monitoring get configmap cluster-monitoring-config -o yaml
oc -n openshift-user-workload-monitoring get pods
```

Os scripts preservam outras chaves do ConfigMap `cluster-monitoring-config` e
ajustam somente `enableUserWorkload` em `data.config.yaml`.

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

## ✅ Validação do laboratório

Este repositório valida somente o CRC/OpenShift Local e recursos de cluster. As
configurações de Keycloak, Grafana, Zabbix, Loki, Tempo e OpenTelemetry ficam
nos respectivos repositórios GitOps.

```bash
cp .env.example .env
scripts/validate-crc.sh
```

Se `crc` ou `oc` não estiverem no `PATH`, o script tenta usar automaticamente
binários conhecidos, como `bin/crc-linux-*/crc`, `~/.local/bin/oc` ou o cache
do CRC. Você também pode fixar `CRC_BIN` e `OC_BIN` no `.env`.

O script verifica status do CRC, login do `oc`, recursos mínimos recomendados,
`enable-cluster-monitoring`, ClusterOperators, namespaces esperados, pods de
monitoramento de plataforma, rotas principais e Applications do Argo CD/OpenShift
GitOps. O UWM nativo só é exigido se `EXPECT_USER_WORKLOAD_MONITORING=true`.

---

## 📋 Observações

- O cluster é provisionado como **Single Node OpenShift (SNO)**.
- A instalação padrão deste repositório usa 40 GiB de RAM e 10 CPUs para reduzir
  pressão de memória na stack completa. Para laboratórios menores, reduza antes
  de iniciar o CRC:
  ```bash
  crc config set memory 32768
  crc config set cpus 8
  ```
- Se `crc` estiver ausente ou apontando para um symlink quebrado, baixe o pacote
  oficial do OpenShift Local, salve em `bin/crc/crc-linux-amd64.tar.xz` e
  reexecute `./install.sh`.

---

## 🧼 Remover ambiente

Para excluir o cluster CRC e limpar o ambiente:

```bash
crc stop
crc delete
```

---

## 📘 Referências

- [Documentação oficial do OpenShift Local](https://docs.redhat.com/en/documentation/red_hat_openshift_local)
- [OpenShift Monitoring/User Workload Monitoring](https://docs.redhat.com/en/documentation/openshift_container_platform/4.14/html/monitoring/configuring-user-workload-monitoring)
- [OpenShift Local no Red Hat Console](https://console.redhat.com/openshift/create/local)
