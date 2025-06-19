@description('Location for resources')
param location string = 'australiaeast'

@description('Admin username for the VM')
param adminUsername string = 'azureuser'

@description('Admin password for the VM')
@secure()
param adminPassword string

resource sa 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: 'flsa${uniqueString(resourceGroup().id)}'
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }
}

resource law 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: 'flowlog-law'
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2022-05-01' = {
  name: 'nsg-app'
  location: location
  properties: {
    securityRules: [
      {
        name: 'deny-web-to-app'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Deny'
          protocol: 'Tcp'
          sourceAddressPrefix: '10.100.1.0/24'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name: 'vnet-demo'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: ['10.100.0.0/16']
    }
    subnets: [
      {
        name: 'web-subnet'
        properties: {
          addressPrefix: '10.100.1.0/24'
        }
      }
      {
        name: 'app-subnet'
        properties: {
          addressPrefix: '10.100.2.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2022-05-01' = {
  name: 'vm-web-pip'
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    sku: {
      name: 'Basic'
    }
  }
}

resource nicWeb 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: 'vm-web-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
}

resource nicApp 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: 'vm-app-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet.properties.subnets[1].id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource vmWeb 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: 'vm-web'
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_B1s' }
    osProfile: {
      computerName: 'vm-web'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18.04-LTS'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicWeb.id
        }
      ]
    }
  }
}

resource vmApp 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: 'vm-app'
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_B1s' }
    osProfile: {
      computerName: 'vm-app'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18.04-LTS'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicApp.id
        }
      ]
    }
  }
}
