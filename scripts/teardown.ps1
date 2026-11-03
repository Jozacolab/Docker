<#
.SYNOPSIS
    Script: teardown.ps1
    Remove a stack e limpa os recursos do cluster Docker Swarm.
#>

Set-Location "$PSScriptRoot\.."

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [TEARDOWN] Limpeza dos Recursos do Docker Swarm" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

Write-Host "[+] Removendo stack 'app_cluster'..." -ForegroundColor Yellow
docker stack rm app_cluster | Out-Null

Write-Host "[*] Aguardando término dos containers..." -ForegroundColor Gray
Start-Sleep -Seconds 10

# Limpar containers DinD se existirem
$dindNodes = @("swarm-manager", "swarm-worker1", "swarm-worker2")
foreach ($node in $dindNodes) {
    $exists = docker ps -a --filter name="^/$node$" -q
    if ($exists) {
        Write-Host "[+] Removendo nó DinD: $node" -ForegroundColor Yellow
        docker rm -f $node | Out-Null
    }
}

if (docker network ls --filter name="^swarm-cluster-net$" -q) {
    docker network rm swarm-cluster-net | Out-Null
}

Write-Host "[SUCESSO] Ambiente limpo com sucesso!" -ForegroundColor Green

