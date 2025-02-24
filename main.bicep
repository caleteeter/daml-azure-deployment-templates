@description('Azure region that will be targeted for resources.')
param location string = resourceGroup().location

@description('Postgres database administrator login name')
@minLength(1)
param postgresAdminLogin string

@description('Postgres database administrator password')
@minLength(8)
@secure()
param postgresAdminPassword string

@description('Company name registered with Digital Asset')
param company string

@description('Version of Canton')
param version string

@description('Username used with Digital Asset')
param username string

@description('Password used with Digital Asset')
@secure()
param password string

// this is used to ensure uniqueness to naming (making it non-deterministic)
param rutcValue string = utcNow()

// the built-in role that allow contributor permissions (create)
// NOTE: there is no built-in creator/contributor role directly with PGaaS
var pgRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

var akssubnet = 'akssubnet'
var pgsubnet = 'pgsubnet'

// allow access to all ips on the internet, for testing, will be removed or adjusted
// for production
var firewallrules= [
  {
    Name: 'allowAzure'
    StartIpAddress: '0.0.0.0'
    EndIpAddress: '0.0.0.0'
  }
  {
    Name: 'allowAllInternet'
    StartIPAddress: '0.0.0.0'
    EndIpAddress: '255.255.255.255'
  }
]

// key vault for backing Kubernetes secrets
resource akv 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: 'a${uniqueString(resourceGroup().id)}akv'
  location: location
  properties: {
    tenantId: tenant().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: [
      {
        objectId: managedIdentity.properties.principalId
        tenantId: managedIdentity.properties.tenantId
        permissions: {
          secrets: [
            'all'
          ]
        }
      }
    ]
  }
}

// container registry for images/charts
resource acr 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' = {
  name: '${uniqueString(resourceGroup().id)}acr'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}

// the identity used for internal service calls for AKS and PGaaS
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: '${uniqueString(resourceGroup().id)}mi'
  location: location
}

// the virtual network used by both AKS and PGaaS
resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: uniqueString(resourceGroup().id)
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.0.0/16'
      ]
    }

    subnets: [
      {
        name: akssubnet
        properties: {
          addressPrefix: '10.1.1.0/24'
        }
      }
      {
        name: pgsubnet
        properties: {
          addressPrefix: '10.1.2.0/24'
        }
      }
    ]
  }

  resource akssubnet1 'subnets' existing = {
    name: akssubnet
  }

  resource pgsubnet1 'subnets' existing = {
    name: pgsubnet
  }
}

// the managed kubernetes (AKS) cluster
resource aks 'Microsoft.ContainerService/managedClusters@2022-05-02-preview' = {
  name: '${uniqueString(resourceGroup().id)}aks'
  location: location
  dependsOn: [
    vnet::akssubnet1
  ]
  properties: {
    dnsPrefix: '${uniqueString(resourceGroup().id)}aks'
    agentPoolProfiles: [
      {
        name: 'agentpool'
        count: 3
        vmSize: 'Standard_D4s_v4'
        availabilityZones: ['1', '2', '3']
        mode: 'System'
        vnetSubnetID: resourceId('Microsoft.Network/virtualNetworks/subnets/', vnet.name, 'akssubnet')
      }
    ]
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
}

// the role assignment using the built-in role to allow the managed identity created in the template
// to have rights to create the database objects in PGaaS instance
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  #disable-next-line use-stable-resource-identifiers simplify-interpolation
  name: '${guid(uniqueString(resourceGroup().id), rutcValue)}'
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', pgRoleId)
    description: 'pgaas'
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// the PGaaS (managed Postgres) instance
resource server 'Microsoft.DBforPostgreSQL/flexibleServers@2022-01-20-preview' = {
  name: '${uniqueString(resourceGroup().id)}pfs'
  location: location
  sku: {
    name: 'Standard_D4ds_v4'
    tier: 'GeneralPurpose'
  }
  dependsOn: [
    vnet::pgsubnet1
  ]
  properties: {
    version: '14'
    administratorLogin: postgresAdminLogin
    administratorLoginPassword: postgresAdminPassword
    availabilityZone: '3'
    highAvailability: {
      mode: 'ZoneRedundant'
      standbyAvailabilityZone: '1'
    }
    storage:{
      storageSizeGB: 32
    }
  }
}

// creating the firewall rules that are applied to the PGaaS instance
@batchSize(1)
resource firewallRules 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2022-01-20-preview' = [for rule in firewallrules: {
  parent: server
  name: '${rule.Name}'
  properties: {
    startIpAddress: rule.StartIpAddress
    endIpAddress: rule.EndIpAddress
  }
}]

// the deployment script that will create assets in the PGaaS instance, initially databases, but additionally the
// k8s deployment
resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: '${uniqueString(resourceGroup().id)}dpy'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities:{
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    arguments: '${managedIdentity.id} ${resourceGroup().name} ${aks.name} ${acr.name} ${company} ${username} ${password} ${version} ${server.name} ${postgresAdminLogin} ${postgresAdminPassword} ${akv.name}'
    forceUpdateTag: '1'
    containerSettings:{
      containerGroupName: '${uniqueString(resourceGroup().id)}ci1'
    }
    primaryScriptUri: 'https://raw.githubusercontent.com/caleteeter/daml-azure-deployment-templates/main/scripts/deploy.sh'
    timeout: 'PT30M'
    cleanupPreference: 'OnExpiration'
    azCliVersion: '2.45.0'
    retentionInterval:'P1D'
  }
}
