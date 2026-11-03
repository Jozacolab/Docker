<#
.SYNOPSIS
    Script: deploy.ps1
    Faz o deploy da aplicação distribuída com alta disponibilidade no Docker Swarm.
#>

$ErrorActionPreference = "Stop"

# Garantir que o diretório de execução seja a raiz do projeto
Set-Location "$PSScriptRoot\.."

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [DEPLOY] Inicializando e Implantando Stack no Docker Swarm" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Verificar se Docker está respondendo
try {
    $swarmState = (docker info --format '{{.Swarm.LocalNodeState}}' 2>$null).Trim()
} catch {
    Write-Error "O daemon do Docker não está em execução. Inicie o Docker antes de continuar."
    exit 1
}

# 2. Inicializar Swarm se inativo
if ($swarmState -ne "active") {
    Write-Host "[+] Docker Swarm inativo. Inicializando Swarm..." -ForegroundColor Yellow
    docker swarm init | Out-Null
    Write-Host "[+] Docker Swarm inicializado com sucesso!" -ForegroundColor Green
} else {
    Write-Host "[i] Docker Swarm já se encontra ATIVO." -ForegroundColor Green
}

# 3. Detectar nós do cluster
$nodeCount = (docker node ls -q | Measure-Object -Line).Lines
Write-Host "[*] Quantidade de nós detectados no cluster: $nodeCount" -ForegroundColor Cyan

$currentNode = (docker node ls --filter "role=manager" --format "{{.Hostname}}").Trim().Split("`n")[0]
Write-Host "[+] Aplicando label 'type=db' no nó manager ($currentNode) para suportar persistência..." -ForegroundColor Green
docker node update --label-add type=db $currentNode | Out-Null

# 4. Escolher stack conforme ambiente
$stackFile = "docker-stack.yml"
if ($nodeCount -le 1) {
    Write-Host "[i] Cluster single-node detectado. Utilizando docker-stack.single-node.yml para evitar restrições de worker." -ForegroundColor Yellow
    $stackFile = "docker-stack.single-node.yml"
} else {
    Write-Host "[i] Cluster multi-nó detectado. Utilizando docker-stack.yml completo." -ForegroundColor Green
}

# 5. Criar redes overlay se não existirem
$networks = @("frontend-net", "backend-net")
foreach ($net in $networks) {
    $exists = docker network ls --filter name="^$net$" -q
    if (-not $exists) {
        Write-Host "[+] Criando rede overlay: $net" -ForegroundColor Green
        docker network create --driver overlay --attachable $net | Out-Null
    } else {
        Write-Host "[i] Rede overlay $net já existe." -ForegroundColor Gray
    }
}

# 6. Realizar deploy da Stack
$stackName = "app_cluster"
Write-Host "[+] Executando deploy da stack '$stackName'..." -ForegroundColor Green
docker stack deploy -c $stackFile $stackName

Write-Host "[*] Aguardando convergência dos serviços (15 segundos)..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# 7. Exibir status dos serviços e tarefas
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [STATUS] Serviços em Execução no Swarm" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
docker service ls

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [STATUS] Tarefas e Réplicas Distribuídas" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
docker stack ps $stackName

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host " [SUCESSO] Aplicação Implantada com Alta Disponibilidade!" -ForegroundColor Green
Write-Host " Frontend Web:        http://localhost" -ForegroundColor White
Write-Host " Backend API via Web: http://localhost/api" -ForegroundColor White
Write-Host " Visualizador Swarm:  http://localhost:8080" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Green

