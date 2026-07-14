#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploys the ARO landing-zone infrastructure foundation to Azure

.DESCRIPTION
    This script deploys the shared network foundation used by the Azure Red Hat
    OpenShift (ARO) cluster that hosts Cohere North:
    - Virtual Network with a private-endpoint subnet

    ARO cluster provisioning and the managed dependencies (Azure Database for
    PostgreSQL, Azure Cache for Redis, Key Vault) are added as separate templates.

.PARAMETER ConfigFile
    Path to the configuration JSON file. Default: config.json

.PARAMETER SkipVNetDeployment
    Skip VNet deployment if it already exists

.PARAMETER DeploymentType
    Type of deployment: 'all', 'vnet'

.PARAMETER SubscriptionId
    Azure subscription ID (optional, will use current subscription if not specified)

.EXAMPLE
    .\deploy.ps1 -ConfigFile .\config.json -DeploymentType all

.EXAMPLE
    .\deploy.ps1 -ConfigFile .\config.prod.json -SkipVNetDeployment
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile = "config.json",

    [Parameter(Mandatory=$false)]
    [switch]$SkipVNetDeployment,

    [Parameter(Mandatory=$false)]
    [ValidateSet('all', 'vnet')]
    [string]$DeploymentType = 'all',

    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Function to write colored output
function Write-Status {
    param(
        [string]$Message,
        [string]$Type = "Info"
    )

    switch ($Type) {
        "Info"    { Write-Host "[INFO] $Message" -ForegroundColor Cyan }
        "Success" { Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
        "Warning" { Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
        "Error"   { Write-Host "[ERROR] $Message" -ForegroundColor Red }
    }
}

# Function to check if Azure CLI is installed
function Test-AzureCLI {
    try {
        $null = az version
        return $true
    }
    catch {
        return $false
    }
}

# Main deployment function
function Start-Deployment {
    Write-Status "Starting ARO landing-zone infrastructure deployment..." "Info"

    # Check if Azure CLI is installed
    if (-not (Test-AzureCLI)) {
        Write-Status "Azure CLI is not installed. Please install it from https://docs.microsoft.com/cli/azure/install-azure-cli" "Error"
        exit 1
    }

    # Check if config file exists
    if (-not (Test-Path $ConfigFile)) {
        Write-Status "Configuration file '$ConfigFile' not found." "Error"
        exit 1
    }

    # Load configuration
    Write-Status "Loading configuration from $ConfigFile..." "Info"
    $config = Get-Content $ConfigFile | ConvertFrom-Json

    # Set subscription if specified
    if ($SubscriptionId) {
        Write-Status "Setting Azure subscription to $SubscriptionId..." "Info"
        az account set --subscription $SubscriptionId
    }

    # Get current subscription
    $currentSub = az account show | ConvertFrom-Json
    Write-Status "Using subscription: $($currentSub.name) ($($currentSub.id))" "Info"

    # Create resource groups
    Write-Status "Creating resource groups..." "Info"

    Write-Status "Creating VNet resource group: $($config.vnetResourceGroup)" "Info"
    az group create --name $config.vnetResourceGroup --location $config.location --output none

    Write-Status "Creating main resource group: $($config.resourceGroup)" "Info"
    az group create --name $config.resourceGroup --location $config.location --output none

    Write-Status "Resource groups created successfully" "Success"

    # Deploy VNet
    if (-not $SkipVNetDeployment -and ($DeploymentType -eq 'all' -or $DeploymentType -eq 'vnet')) {
        Write-Status "Deploying Virtual Network..." "Info"

        $vnetDeploymentName = "vnet-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

        az deployment group create `
            --name $vnetDeploymentName `
            --resource-group $config.vnetResourceGroup `
            --template-file vnet.bicep `
            --parameters vnet.parameters.json `
            --output none

        if ($LASTEXITCODE -eq 0) {
            Write-Status "Virtual Network deployed successfully" "Success"
        } else {
            Write-Status "Virtual Network deployment failed" "Error"
            exit 1
        }
    }

    Write-Status "Deployment completed successfully!" "Success"
    Write-Status "Resource Group: $($config.resourceGroup)" "Info"
    Write-Status "VNet Resource Group: $($config.vnetResourceGroup)" "Info"
}

# Execute deployment
try {
    Start-Deployment
}
catch {
    Write-Status "Deployment failed with error: $_" "Error"
    exit 1
}
