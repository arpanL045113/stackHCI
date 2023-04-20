Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
Install-PackageProvider -Name NuGet -Force 
Install-Module -Name PowershellGet -Force

Install-Module -Name AksHci -Repository PSGallery -AcceptLicense -Force


<##Register the resource provider to your subscription
Ahead of the registration process, you must enable the appropriate resource provider in Azure for 
AKS on Azure Stack HCI integration. To do that, run the following PowerShell script##>

Register-AzResourceProvider -ProviderNamespace Microsoft.Kubernetes
Register-AzResourceProvider -ProviderNamespace Microsoft.KubernetesConfiguration

##To verify the registration, run the following PowerShell commands:##
Get-AzResourceProvider -ProviderNamespace Microsoft.Kubernetes
Get-AzResourceProvider -ProviderNamespace Microsoft.KubernetesConfiguration


# For an Interactive Login with a user account:
Set-AksHciRegistration -SubscriptionId $sub -ResourceGroupName $rg


Set-AksHciRegistration -SubscriptionId $sub -ResourceGroupName $rg -UseDeviceAuthentication


# To use your Service Principal, first enter your Service Principal credentials (app ID, secret) then set the registration
$cred = Get-Credential
Set-AksHciRegistration -SubscriptionId $sub -ResourceGroupName $rg -TenantId $tenant -Credential $cred


#import AKShci module####

Import-Module AksHci

<##it's important to validate your single node to ensure it meets all the requirements to install AKS on Azure Stack HCI. 
un the following command in your administrator PowerShell window#>

Initialize-AksHciNode

##run the following commands to create some folders that will be used during the deployment proces##

New-Item -Path "C:\" -Name "AKS-HCI" -ItemType "directory" -Force
New-Item -Path "C:\AKS-HCI\" -Name "Images" -ItemType "directory" -Force
New-Item -Path "C:\AKS-HCI\" -Name "WorkingDir" -ItemType "directory" -Force
New-Item -Path "C:\AKS-HCI\" -Name "Config" -ItemType "directory" -Force

##this is only for Static IP, NOT DHCP ####

##Create a networking configuration for the AKS deployment on Azure Stack HCI to use.

$vnet = New-AksHciNetworkSetting -name "mgmtvnet" -vSwitchName "InternalNAT" -gateway "10.0.0.1" -dnsservers "192.168.0.1" `
    -ipaddressprefix "192.168.0.0/16" -k8snodeippoolstart "192.168.0.3" -k8snodeippoolend "192.168.0.149" `
    -vipPoolStart "192.168.0.150" -vipPoolEnd "192.168.0.250"

<#With the networking configuration defined, you can now finalize the configuration of your AKS deployment on Azure Stack HCI#>

Set-AksHciConfig -vnet $vnet -imageDir "C:\AKS-HCI\Images" -workingDir "C:\AKS-HCI\WorkingDir" `
   -cloudConfigLocation "C:\AKS-HCI\Config" -Verbose

##With the configuration files finalized, finalize the registration configuration wit your AZ subscription.##

# Login to Azure
Connect-AzAccount

# Optional - if you wish to switch to a different subscription
# First, get all available subscriptions as the currently logged in user
$subList = Get-AzSubscription
# Display those in a grid, select the chosen subscription, then press OK.
if (($subList).count -gt 1) {
    $subList | Out-GridView -OutputMode Single | Set-AzContext
}

# Retrieve the subscription and tenant ID
$sub = (Get-AzContext).Subscription.Id
$tenant = (Get-AzContext).Tenant.Id

# First create a resource group in Azure that will contain the registration artifacts
$rg = (New-AzResourceGroup -Name AksHciAzureEval -Location "East US" -Force).ResourceGroupName


###we need to declare the ID, Secrets etc before running the Set-AksHciRegistration, it's required as we're using Service PRincipal

$azureAplicationId ="49f623eb-b114-43a2-ad70-5ea07f1f03f1"
$azureTenantId= "18a59a81-eea8-4c30-948a-d8824cdc2580"
$azurePassword = ConvertTo-SecureString "2uL8Q~~XfpgdK9K1FsdVK4BFw33sbNEbiHCMbdei" -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($azureAplicationId , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $azureTenantId  -ServicePrincipal 

$sub="c4af9cc0-a3c0-46ac-ae12-8be76ca1506e"
$rg="AksHciAzureEval"
$tenant="18a59a81-eea8-4c30-948a-d8824cdc2580"



Set-AksHciRegistration -SubscriptionId $sub -ResourceGroupName $rg -TenantId $tenant -Credential $psCred


#install

Install-AksHci


#get k8 version

# Show available Kubernetes versions
Get-AksHciKubernetesVersion


#create aks cluster

New-AksHciCluster -name akshciclus001 -nodePoolName linuxnodepool -controlPlaneNodeCount 1 -nodeCount 1 -osType linux -kubernetesVersion v1.23.15