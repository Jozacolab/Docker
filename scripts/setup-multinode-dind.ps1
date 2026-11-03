<#
.SYNOPSIS
    Script: setup-multinode-dind.ps1
    Cria um cluster Docker Swarm multi-nó real (1 Manager + 2 Workers)
    utilizando Docker-in-Docker (DinD).
#>

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [DOCKER SWARM] Criando Cluster Multi-Nó com DinD" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$networkName = "swarm-cluster-net"

# 1. Criar rede bridge para os nós se comunicarem
$netExists = docker network ls --filter name="^$networkName$" -q
if (-not $netExists) {
    Write-Host "[+] Criando rede interna de nós: $networkName" -ForegroundColor Green
    docker network create --driver bridge $networkName | Out-Null
}

# 2. Criar containers dos nós
$nodes = @("swarm-manager", "swarm-worker1", "swarm-worker2")
foreach ($node in $nodes) {
    $existing = docker ps -a --filter name="^/$node$" -q
    if ($existing) {
        Write-Host "[!] Removendo nó anterior: $node" -ForegroundColor Yellow
        docker rm -f $node | Out-Null
    }
    Write-Host "[+] Inicializando nó DinD: $node" -ForegroundColor Green
    docker run -d --privileged `
        --name $node `
        --hostname $node `
        --network $networkName `
        -p 80:80 -p 8080:8080 `
        docker:dind | Out-Null
}

Write-Host "[*] Aguardando daemons do Docker inicializarem..." -ForegroundColor Gray
Start-Sleep -Seconds 5

# 3. Inicializar Swarm no Manager
Write-Host "[+] Inicializando Docker Swarm no swarm-manager..." -ForegroundColor Green
$managerIp = docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' swarm-manager
docker exec swarm-manager docker swarm init --advertise-addr $managerIp

# Obter token de Worker
$workerToken = (docker exec swarm-manager docker swarm join-token -q worker).Trim()
Write-Host "[*] Token de Worker gerado: $workerToken" -ForegroundColor Gray

# 4. Ingressar Workers no Cluster
Write-Host "[+] Conectando swarm-worker1 ao cluster..." -ForegroundColor Green
docker exec swarm-worker1 docker swarm join --token $workerToken "${managerIp}:2377"

Write-Host "[+] Conectando swarm-worker2 ao cluster..." -ForegroundColor Green
docker exec swarm-worker2 docker swarm join --token $workerToken "${managerIp}:2377"

# 5. Adicionar labels nos nós para gerenciamento de alocação
Write-Host "[+] Aplicando labels de alocação nos nós..." -ForegroundColor Green
docker exec swarm-manager docker node update --label-add type=db swarm-worker1
docker exec swarm-manager docker node update --label-add role=web swarm-worker2

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host " [SUCESSO] Cluster Docker Swarm Multi-Nó Inicializado!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
docker exec swarm-manager docker node ls
Write-Host "==========================================================" -ForegroundColor Green

