# Projeto Fase 2: Administração de Containers em Ambientes Distribuídos (Docker Swarm)

Este repositório contém a implementação completa, automatizada e documentada da **Fase 2 - Gerenciamento de Clusters, Serviços Distribuídos e Configuração de Redes no Docker Swarm**.

---

## 📁 Estrutura do Repositório

```text
├── docker-stack.yml                      # Manifesto declarativo da stack de serviços para ambiente multi-nó
├── docker-stack.single-node.yml          # Manifesto adaptado para testes rápidos em nó único (manager/local)
├── generate_docx.py                      # Script gerador do relatório Word (.docx) formatado
├── ENTREGA_FASE2_DOCKER_SWARM.md         # Relatório completo da entrega em Markdown (para leitura/GitHub)
├── ENTREGA_Fase2_Docker_Swarm.docx       # Arquivo Word preenchido no template oficial para entrega
├── TEMPLATE ENTREGA_Fase 2_...docx       # Template original de referência
├── nginx/
│   └── default.conf                      # Configuração do Nginx (Reverse proxy, /health check e balanceamento)
└── scripts/
    ├── deploy.ps1 / deploy.sh            # Script de deploy e convergência da stack
    ├── test-cluster.ps1 / test-cluster.sh# Bateria automatizada com os 5 testes de resiliência e alta disponibilidade
    ├── setup-multinode-dind.ps1 / .sh    # Criação de cluster com 3 nós reais (1 Manager + 2 Workers via DinD)
    └── teardown.ps1 / teardown.sh        # Limpeza completa de containers, redes e stacks
```

---

## 🚀 Opções para Execução dos Testes

Você pode testar este cluster de três maneiras:

### Opção A: Play with Docker (Recomendada para Teste Imediato sem Requisitos de Hardware)
Se você não deseja reiniciar o computador ou alterar configurações de BIOS agora:
1. Acesse: [https://labs.play-with-docker.com/](https://labs.play-with-docker.com/) e faça login gratuito com sua conta Docker Hub.
2. Clique em **"Add New Instance"** 3 vezes (criando `node1`, `node2` e `node3`).
3. No `node1` (Manager), inicialize o swarm:
   ```bash
   docker swarm init --advertise-addr $(hostname -i)
   ```
4. Copie o comando `docker swarm join ...` fornecido e cole no `node2` e no `node3`.
5. No `node1`, clone ou crie os arquivos da stack e execute:
   ```bash
   docker stack deploy -c docker-stack.yml app_cluster
   ```
6. Execute o script de testes:
   ```bash
   bash scripts/test-cluster.sh
   ```

---

### Opção B: No seu Windows Local (Docker Desktop)
> ⚠️ **Diagnóstico detectado no seu computador:**
> A verificação de sistema apontou: `Virtualização Habilitada no Firmware: Não`.  
> Para que o Docker Desktop / WSL2 funcione no seu Windows, basta reiniciar o computador, entrar na **BIOS/UEFI** (pressionando `DEL` ou `F2` ao ligar) e habilitar a opção de virtualização de hardware:
> * Processadores AMD: Habilitar **SVM Mode** (Secure Virtual Machine).
> * Processadores Intel: Habilitar **Intel Virtualization Technology (VT-x)**.
>
> Após salvar e iniciar o Windows, o Docker Desktop iniciará automaticamente.

Com o Docker ativo:
1. Abra o PowerShell na pasta do projeto:
   ```powershell
   # Deploy automático da aplicação:
   .\scripts\deploy.ps1
   ```
2. Execução da bateria completa de testes:
   ```powershell
   .\scripts\test-cluster.ps1
   ```
3. Acessar no navegador:
   * **Frontend Web:** [http://localhost](http://localhost)
   * **Backend API (via Proxy):** [http://localhost/api](http://localhost/api)
   * **Visualizador Swarm (Topologia em tempo real):** [http://localhost:8080](http://localhost:8080)

---

### Opção C: Cluster Multi-Nó Local via Docker-in-Docker (DinD)
Para testar exatamente com 3 nós isolados (`swarm-manager`, `swarm-worker1`, `swarm-worker2`) em sua máquina local:
```powershell
# Cria a rede e os 3 nós simulados:
.\scripts\setup-multinode-dind.ps1

# Acessa o nó manager para interagir:
docker exec -it swarm-manager sh
```

---

## 🧪 Bateria de Testes Implementada (`test-cluster.ps1` / `test-cluster.sh`)

O script executa e comprova os seguintes cenários:

1. **Balanceamento de Carga (Ingress Routing Mesh):** Emite requisições sucessivas para `http://localhost/api` comprovando que o tráfego é distribuído em *round-robin* entre as réplicas ativas via IPVS e DNS interno.
2. **Auto-Recuperação (Self-Healing):** Mata abruptamente um container ativo com `docker rm -f`. O Swarm detecta a divergência e instancia uma nova réplica em menos de 4 segundos.
3. **Rolling Update com Zero-Downtime:** Dispara uma atualização no serviço com a diretiva `order: start-first` enquanto realiza requisições ininterruptas. Todas as requisições retornam HTTP 200 (0% de perda).
4. **Esvaziamento de Nó (Drain / Failover):** Coloca um nó em modo `drain`. As tarefas são migradas instantaneamente para os demais nós sem indisponibilidade.
5. **Segmentação e Isolamento de Redes Overlay:** Demonstra que containers da rede `frontend-net` conseguem se comunicar com o `backend-api`, mas estão estritamente bloqueados de contatar diretamente a porta 6379 do `database` (Redis) na rede `backend-net`.

---

## 📄 Arquivos de Entrega da Atividade

1. **Documento Word Oficial:**  
   `ENTREGA_Fase2_Docker_Swarm.docx`  
   *Preenchido e formatado rigorosamente de acordo com o template oficial, contendo tabelas estilizadas, caixas de código sombreadas, comandos detalhados e análise crítica para as 5 seções requeridas.*
2. **Documento Markdown de Consulta:**  
   `ENTREGA_FASE2_DOCKER_SWARM.md`  
   *Versão completa em Markdown com diagramas Mermaid, equações matemáticas de quorum Raft e detalhamento arquitetural.*

---

## 🧹 Limpeza do Ambiente
Para remover a stack e os recursos criados após concluir os testes:
```powershell
.\scripts\teardown.ps1
```
