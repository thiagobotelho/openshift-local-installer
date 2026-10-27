# Instalação e bootstrap

## O que observar

install.sh prepara virtualização, CRC e bootstrap GitOps. Leia cada função antes de executar e use ARGOCD_GITOPS_REF com um SHA aprovado para reproduzir uma instalação. Um exemplo de formato é um SHA completo de 40 caracteres obtido do commit validado, nunca um valor inventado. Não use reset de CRC como correção genérica.

## Roteiro de leitura e validação

1. Leia o README e identifique o componente que recebe a configuração.
2. Confira namespaces, seletores, portas, identidades e dependências nos exemplos.
3. Ajuste apenas os campos necessários em um ambiente isolado; não use credenciais de produção.
4. Valide sintaxe e contratos locais antes de aplicar. Registre o resultado real separado deste guia.
5. Execute um caso permitido e um caso negado, conferindo a causa da resposta.
6. Defina reversão por recurso/arquivo e preserve dados persistentes antes de mudanças.

Os comentários dos manifests explicam escolhas; não comprovam disponibilidade do componente. Exemplos fora de entradas Kustomize não são implantados automaticamente.
