param(
    [string]$Mode = "full"  # "core" ou "full"
)

$ErrorActionPreference = "Stop"

Write-Host "Mode de test : $Mode"

# ---- Lancement des services ----
if ($Mode -eq "core") {
    Write-Host "Lancement du broker et du backend..."
    docker compose up -d --build broker backend
} else {
    Write-Host "Lancement du broker, backend et front..."
    docker compose up -d --build
}

# ---- Fonction helper : attendre un endpoint HTTP ----
function Wait-Http {
    param(
        [string]$Url,
        [string]$Name,
        [int]$MaxTries = 30
    )

    Write-Host "Attente de $Name sur $Url ..."

    for ($i = 1; $i -le $MaxTries; $i++) {
        try {
            $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 3
            if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 500) {
                Write-Host "$Name OK"
                return
            }
        } catch {
            Start-Sleep -Seconds 2
        }
    }

    throw "$Name ne repond pas apres $MaxTries tentatives."
}

# ---- Test du backend ----
Wait-Http -Url "http://localhost:8000/health" -Name "Backend"

# ---- Test du front si mode full ----
if ($Mode -eq "full") {
    Wait-Http -Url "http://localhost:8085/" -Name "Front"
}

Write-Host "Smoke test reussi."

# ---- Nettoyage ----
Write-Host "Arret des services..."
docker compose down

Write-Host "Termine."
