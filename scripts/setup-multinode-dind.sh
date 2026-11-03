#!/usr/bin/env bash
# ==============================================================================
# Script: setup-multinode-dind.sh
# Objetivo: Criar um cluster Docker Swarm multi-nó real (1 Manager + 2 Workers)
# utilizando Docker-in-Docker (DinD). Funciona em qualquer máquina com Docker!
# ==============================================================================

set -e

echo "=========================================================="
echo " [DOCKER SWARM] Criando Cluster Multi-Nó com DinD"
echo "=========================================================="

NETWORK_NAME="swarm-cluster-net"

# 1. Criar rede bridge para os nós se comunicarem
if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    echo "[+] Criando rede interna de nós: $NETWORK_NAME"
    docker network create --driver bridge "$NETWORK_NAME"
fi

# 2. Criar containers dos nós (1 Manager, 2 Workers)
NODES=("swarm-manager" "swarm-worker1" "swarm-worker2")
for NODE in "${NODES[@]}"; do
    if docker ps -a --format '{{.Names}}' | grep -Eq "^${NODE}\$"; then
        echo "[!] Removendo nó anterior: $NODE"
        docker rm -f "$NODE" >/dev/null 2>&1
    fi
    echo "[+] Inicializando nó DinD: $NODE"
    docker run -d --privileged \
        --name "$NODE" \
        --hostname "$NODE" \
        --network "$NETWORK_NAME" \
        docker:dind
done

echo "[*] Aguardando daemons do Docker inicializarem dentro dos containers..."
sleep 5

# 3. Inicializar Swarm no Manager
echo "[+] Inicializando Docker Swarm no swarm-manager..."
MANAGER_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' swarm-manager)
docker exec swarm-manager docker swarm init --advertise-addr "$MANAGER_IP"

# Obter token de Worker
WORKER_TOKEN=$(docker exec swarm-manager docker swarm join-token -q worker)
echo "[*] Token de Worker gerado: $WORKER_TOKEN"

# 4. Ingressar Workers no Cluster
echo "[+] Conectando swarm-worker1 ao cluster..."
docker exec swarm-worker1 docker swarm join --token "$WORKER_TOKEN" "$MANAGER_IP":2377

echo "[+] Conectando swarm-worker2 ao cluster..."
docker exec swarm-worker2 docker swarm join --token "$WORKER_TOKEN" "$MANAGER_IP":2377

# 5. Adicionar labels nos nós para gerenciamento de alocação (Placement Constraints)
echo "[+] Aplicando labels de alocação nos nós..."
docker exec swarm-manager docker node update --label-add type=db swarm-worker1
docker exec swarm-manager docker node update --label-add role=web swarm-worker2

echo ""
echo "=========================================================="
echo " [SUCESSO] Cluster Docker Swarm Multi-Nó Inicializado!"
echo "=========================================================="
docker exec swarm-manager docker node ls
echo "=========================================================="

