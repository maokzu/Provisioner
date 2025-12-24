# Script de build pour Provisioner
# Cree un ZIP avec la structure correcte pour CurseForge/GitHub

# Couleurs pour les messages
$ErrorActionPreference = "Stop"

Write-Host "=== Build Provisioner ===" -ForegroundColor Cyan

# Lire la version depuis le fichier .toc
$tocFile = "Provisioner.toc"
if (-not (Test-Path $tocFile)) {
    Write-Host "Erreur: Fichier $tocFile introuvable!" -ForegroundColor Red
    exit 1
}

$version = (Select-String -Path $tocFile -Pattern "## Version: (.+)" | ForEach-Object { $_.Matches.Groups[1].Value }).Trim()
if (-not $version) {
    Write-Host "Erreur: Version introuvable dans $tocFile!" -ForegroundColor Red
    exit 1
}

Write-Host "Version detectee: $version" -ForegroundColor Green

# Nom du fichier ZIP de sortie
$zipName = "Provisioner-$version.zip"

# Creer le dossier de build temporaire
$buildDir = "build"
$addonDir = Join-Path $buildDir "Provisioner"

Write-Host "Creation du dossier de build..." -ForegroundColor Yellow

# Nettoyer le dossier de build s'il existe
if (Test-Path $buildDir) {
    Remove-Item -Path $buildDir -Recurse -Force
}

# Creer la structure de dossiers
New-Item -ItemType Directory -Path $addonDir -Force | Out-Null

# Liste des fichiers a inclure dans le ZIP
$filesToInclude = @(
    "Provisioner.toc",
    "Provisioner.lua",
    "Provisioner.xml",
    "Locales.lua",
    "README.md",
    "LICENSE"
)

Write-Host "Copie des fichiers..." -ForegroundColor Yellow

# Copier les fichiers
foreach ($file in $filesToInclude) {
    if (Test-Path $file) {
        Copy-Item -Path $file -Destination $addonDir -Force
        Write-Host "  OK $file" -ForegroundColor Gray
    }
    else {
        Write-Host "  WARN $file (fichier manquant, ignore)" -ForegroundColor DarkYellow
    }
}

# Copier le dossier media s'il existe
if (Test-Path "media") {
    Copy-Item -Path "media" -Destination $addonDir -Recurse -Force
    Write-Host "  OK media/" -ForegroundColor Gray
}

# Supprimer l'ancien ZIP s'il existe
if (Test-Path $zipName) {
    Write-Host "Suppression de l'ancien ZIP..." -ForegroundColor Yellow
    Remove-Item -Path $zipName -Force
}

# Creer le ZIP
Write-Host "Creation du fichier ZIP..." -ForegroundColor Yellow
Compress-Archive -Path (Join-Path $buildDir "*") -DestinationPath $zipName -CompressionLevel Optimal

# Nettoyer le dossier de build
Write-Host "Nettoyage..." -ForegroundColor Yellow
Remove-Item -Path $buildDir -Recurse -Force

# Verifier que le ZIP a ete cree
if (Test-Path $zipName) {
    $zipSize = (Get-Item $zipName).Length / 1KB
    Write-Host ""
    Write-Host "Build termine avec succes!" -ForegroundColor Green
    Write-Host "  Fichier: $zipName" -ForegroundColor Cyan
    Write-Host "  Taille: $([math]::Round($zipSize, 2)) KB" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Le ZIP contient un dossier Provisioner (sans version)" -ForegroundColor Gray
}
else {
    Write-Host ""
    Write-Host "Erreur lors de la creation du ZIP!" -ForegroundColor Red
    exit 1
}
