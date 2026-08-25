#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploys the ARO landing-zone infrastructure foundation to Azure

.DESCRIPTION
    This script deploys the shared network foundation and Azure Red Hat
    OpenShift (ARO) cluster that hosts Cohere North.

.PARAMETER ConfigFile
    Path to the configuration JSON file. Default: config.json

.PARAMETER SkipVNetDeployment
    Skip VNet deployment if it already exists

.PARAMETER DeploymentType
    Type of deployment: 'all', 'vnet', or 'aro'

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
    [ValidateSet('all', 'vnet', 'aro')]
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

function Assert-AroConfiguration {
    param(
        [PSCustomObject]$Configuration
    )

    $requiredProperties = @(
        'location',
        'resourceGroup',
        'vnetResourceGroup',
        'vnetName',
        'managedResourceGroupName',
        'clusterName',
        'domain'
    )

    foreach ($property in $requiredProperties) {
        if ([string]::IsNullOrWhiteSpace([string]$Configuration.$property)) {
            throw "Configuration property '$property' is required for an ARO deployment."
        }
    }

    if ([string]::IsNullOrWhiteSpace($env:ARO_PULL_SECRET)) {
        throw 'Environment variable ARO_PULL_SECRET is required for an ARO deployment.'
    }
}

function Assert-AroClusterState {
    param(
        [PSCustomObject]$Configuration
    )

    $clusterState = az aro list `
        --resource-group $Configuration.resourceGroup `
        --query "[?name=='$($Configuration.clusterName)'].provisioningState | [0]" `
        --output tsv

    if ($LASTEXITCODE -ne 0) {
        throw "Unable to query the existing ARO cluster state."
    }

    if ($clusterState -eq 'Failed') {
        throw "ARO cluster '$($Configuration.clusterName)' is in Failed state. Microsoft requires failed cluster creations to be deleted before retrying. Run 'az aro delete --resource-group $($Configuration.resourceGroup) --name $($Configuration.clusterName) --yes', wait for deletion to finish, then rerun this deployment."
    }

    if ($clusterState -eq 'Deleting') {
        throw "ARO cluster '$($Configuration.clusterName)' is still deleting. Wait until it is removed, then rerun this deployment."
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

    if ($DeploymentType -eq 'all' -or $DeploymentType -eq 'aro') {
        Assert-AroConfiguration -Configuration $config
    }

    # Set subscription if specified
    if ($SubscriptionId) {
        Write-Status "Setting Azure subscription to $SubscriptionId..." "Info"
        az account set --subscription $SubscriptionId
    }

    # Get current subscription
    $currentSub = az account show | ConvertFrom-Json
    Write-Status "Using subscription: $($currentSub.name) ($($currentSub.id))" "Info"

    if ($DeploymentType -eq 'all' -or $DeploymentType -eq 'aro') {
        Assert-AroClusterState -Configuration $config
    }

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
            --template-file (Join-Path $PSScriptRoot 'vnet.bicep') `
            --parameters `
                "vnetName=$($config.vnetName)" `
                "peSubnetName=$($config.subnetName)" `
            --output none

        if ($LASTEXITCODE -eq 0) {
            Write-Status "Virtual Network deployed successfully" "Success"
        } else {
            Write-Status "Virtual Network deployment failed" "Error"
            exit 1
        }
    }

    if ($DeploymentType -eq 'all' -or $DeploymentType -eq 'aro') {
        Write-Status "Resolving the Azure Red Hat OpenShift resource-provider identity..." "Info"
        $aroResourceProviderObjectId = az ad sp list `
            --filter "appId eq 'f1dd0a37-89c6-4e07-bcd1-ffd3d43d8875'" `
            --query '[0].id' `
            --output tsv

        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($aroResourceProviderObjectId)) {
            throw 'Unable to resolve the Azure Red Hat OpenShift resource-provider identity.'
        }

        Write-Status "Deploying Azure Red Hat OpenShift cluster..." "Info"
        $aroDeploymentName = "aro-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        $aroParameters = @(
            "location=$($config.location)"
            "clusterResourceGroupName=$($config.resourceGroup)"
            "networkResourceGroupName=$($config.vnetResourceGroup)"
            "managedResourceGroupName=$($config.managedResourceGroupName)"
            "clusterName=$($config.clusterName)"
            "domain=$($config.domain)"
            "vnetName=$($config.vnetName)"
            "aroResourceProviderObjectId=$aroResourceProviderObjectId"
            "pullSecret=$($env:ARO_PULL_SECRET)"
        )

        if (-not [string]::IsNullOrWhiteSpace([string]$config.openShiftVersion)) {
            $aroParameters += "openShiftVersion=$($config.openShiftVersion)"
        }

        az deployment sub create `
            --name $aroDeploymentName `
            --location $config.location `
            --template-file (Join-Path $PSScriptRoot 'aro.bicep') `
            --parameters $aroParameters `
            --output none

        if ($LASTEXITCODE -eq 0) {
            Write-Status "Azure Red Hat OpenShift cluster deployed successfully" "Success"
        } else {
            Write-Status "Azure Red Hat OpenShift cluster deployment failed" "Error"
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
