#!/usr/bin/env bash
# ==============================================================================
# Script: deploy.sh
# Objetivo: Deploy automatizado da aplicação com alta disponibilidade no Swarm
# ==============================================================================

set -e

echo "=========================================================="
echo " [DEPLOY] Inicializando e Implantando Stack no Docker Swarm"
echo "=========================================================="

# 1. Verificar estado do Swarm
SWARM_STATE=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || echo "inactive")
if [ "$SWARM_STATE" != "active" ]; then
    echo "[+] Swarm inativo. Inicializando cluster Swarm..."
    docker swarm init
else
    echo "[i] Docker Swarm já se encontra ATIVO."
fi

# 2. Contar nós e aplicar labels
NODE_COUNT=$(docker node ls -q | wc -l)
echo "[*] Quantidade de nós detectados: $NODE_COUNT"

MANAGER_NODE=$(docker node ls --filter "role=manager" --format "{{.Hostname}}" | head -n 1)
echo "[+] Garantindo label 'type=db' no nó $MANAGER_NODE..."
docker node update --label-add type=db "$MANAGER_NODE" >/dev/null 2>&1 || true

STACK_FILE="docker-stack.yml"
if [ "$NODE_COUNT" -le 1 ]; then
    echo "[i] Cluster single-node detectado. Utilizando docker-stack.single-node.yml."
    STACK_FILE="docker-stack.single-node.yml"
else
    echo "[i] Cluster multi-nó detectado. Utilizando docker-stack.yml."
fi

# 3. Criar redes overlay antecipadamente
for NET in frontend-net backend-net; do
    if ! docker network inspect "$NET" >/dev/null 2>&1; then
        echo "[+] Criando rede overlay: $NET"
        docker network create --driver overlay --attachable "$NET"
    fi
done

# 4. Deploy da stack
STACK_NAME="app_cluster"
echo "[+] Executando docker stack deploy -c $STACK_FILE $STACK_NAME..."
docker stack deploy -c "$STACK_FILE" "$STACK_NAME"

echo "[*] Aguardando 15 segundos para estabilização dos serviços..."
sleep 15

# 5. Listar serviços
echo ""
echo "=========================================================="
echo " [STATUS] Serviços Ativos no Swarm"
echo "=========================================================="
docker service ls

echo ""
echo "=========================================================="
echo " [STATUS] Tarefas Distribuídas"
echo "=========================================================="
docker stack ps "$STACK_NAME"

echo ""
echo "=========================================================="
echo " [SUCESSO] Aplicação Implantada com Alta Disponibilidade!"
echo " Frontend Web:        http://localhost"
echo " Backend API via Web: http://localhost/api"
echo " Visualizador Swarm:  http://localhost:8080"
echo "=========================================================="

