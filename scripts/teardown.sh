#!/usr/bin/env bash
# ==============================================================================
# Script: teardown.sh
# Objetivo: Limpar recursos e remover a stack do Docker Swarm
# ==============================================================================

echo "=========================================================="
echo " [TEARDOWN] Limpeza dos Recursos do Docker Swarm"
echo "=========================================================="

echo "[+] Removendo stack 'app_cluster'..."
docker stack rm app_cluster >/dev/null 2>&1 || true

echo "[*] Aguardando término das tarefas..."
sleep 8

# Limpar nós DinD caso tenham sido usados
for NODE in swarm-manager swarm-worker1 swarm-worker2; do
    if docker ps -a --format '{{.Names}}' | grep -Eq "^${NODE}\$"; then
        echo "[+] Removendo nó DinD: $NODE"
        docker rm -f "$NODE" >/dev/null 2>&1 || true
    fi
done

if docker network inspect swarm-cluster-net >/dev/null 2>&1; then
    docker network rm swarm-cluster-net >/dev/null 2>&1 || true
fi

echo "[SUCESSO] Ambiente limpo com sucesso!"

