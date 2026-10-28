# Instalação e bootstrap


install.sh prepara virtualização, CRC e bootstrap GitOps. Leia cada função antes de executar e use ARGOCD_GITOPS_REF com um SHA aprovado para reproduzir uma instalação. Um exemplo de formato é um SHA completo de 40 caracteres obtido do commit validado, nunca um valor inventado. Não use reset de CRC como correção genérica.

## Após o bootstrap

Instalação do CRC, DNS e capacidade do host são pré-requisitos da plataforma. Depois do bootstrap, a instalação e a operação dos componentes ficam em argocd-gitops. Para adicionar Kiali ou tracing, selecione o perfil opcional nesse projeto; não execute novamente a instalação do CRC nem recrie a VM para habilitar um componente.
