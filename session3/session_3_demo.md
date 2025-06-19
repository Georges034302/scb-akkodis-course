## 🧪 Lab Title: NSG Flow Visibility Lab – 🔒 Monitor and Block Intra-VNet Traffic

---

### 🛠️ Prerequisites:

- Azure Subscription with Contributor or Owner access
- Azure CLI installed and authenticated

---

## 🧭 Step-by-Step Lab Instructions

---

### 🚀 Step 1: Deploy Infrastructure

**Goal:** Provision a secure VNet setup with NSG and diagnostic visibility via Flow Logs

---

#### 🧱 Option A: Deploy with Bicep

1. Save the following Bicep file as `nsg_flow_lab.bicep`:

```bicep
param location string = 'australiaeast'
param adminUsername string = 'azureuser'
@secure()
param adminPassword string

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-flow-lab'
  location: location
}

resource sa 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: 'flowlogstorage${uniqueString(resourceGroup().id)}'
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
        sku: '18_04-lts'
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
        sku: '18_04-lts'
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

resource flowLog 'Microsoft.Network/networkWatchers/flowLogs@2022-05-01' = {
  name: 'networkWatcher_australiaeast/flowlog-nsg-app'
  location: location
  properties: {
    targetResourceId: nsg.id
    enabled: true
    storageId: sa.id
    format: {
      type: 'JSON'
      version: 2
    }
    flowAnalyticsConfiguration: {
      networkWatcherFlowAnalyticsConfiguration: {
        enabled: true
        workspaceId: law.properties.customerId
        workspaceRegion: location
        workspaceResourceId: law.id
        trafficAnalyticsInterval: 10
      }
    }
  }
  dependsOn: [
    sa
    law
    nsg
  ]
}
```

2. Deploy the Bicep file:

```bash
az group create --name rg-flow-lab --location australiaeast
az deployment group create \
  --resource-group rg-flow-lab \
  --template-file nsg_flow_lab.bicep \
  --parameters adminPassword='YourSecureP@ssword123'
```

---

#### 💻 Option B: Deploy Using Azure CLI

```bash
# Set variables
RG="rg-flow-lab"
LOCATION="australiaeast"
VNET="vnet-demo"
SUBNET_WEB="web-subnet"
SUBNET_APP="app-subnet"
NSG="nsg-app"
USERNAME="azureuser"
PASSWORD="YourSecureP@ssword123"
VM_WEB="vm-web"
VM_APP="vm-app"

# Create resource group
az group create --name $RG --location $LOCATION

# Create VNet and subnets
az network vnet create \
  --resource-group $RG \
  --name $VNET \
  --address-prefix 10.100.0.0/16 \
  --subnet-name $SUBNET_WEB \
  --subnet-prefix 10.100.1.0/24

az network vnet subnet create \
  --resource-group $RG \
  --vnet-name $VNET \
  --name $SUBNET_APP \
  --address-prefix 10.100.2.0/24

# Create NSG and rule
az network nsg create --resource-group $RG --name $NSG

az network nsg rule create \
  --resource-group $RG \
  --nsg-name $NSG \
  --name deny-web-to-app \
  --priority 100 \
  --direction Inbound \
  --access Deny \
  --protocol Tcp \
  --source-address-prefixes 10.100.1.0/24 \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges 22

# Associate NSG to app-subnet
az network vnet subnet update \
  --resource-group $RG \
  --vnet-name $VNET \
  --name $SUBNET_APP \
  --network-security-group $NSG

# Create NICs
az network nic create \
  --resource-group $RG \
  --name ${VM_WEB}-nic \
  --vnet-name $VNET \
  --subnet $SUBNET_WEB

az network nic create \
  --resource-group $RG \
  --name ${VM_APP}-nic \
  --vnet-name $VNET \
  --subnet $SUBNET_APP

# Create VMs
az vm create \
  --resource-group $RG \
  --name $VM_WEB \
  --nics ${VM_WEB}-nic \
  --image UbuntuLTS \
  --admin-username $USERNAME \
  --admin-password $PASSWORD \
  --authentication-type password

az vm create \
  --resource-group $RG \
  --name $VM_APP \
  --nics ${VM_APP}-nic \
  --image UbuntuLTS \
  --admin-username $USERNAME \
  --admin-password $PASSWORD \
  --authentication-type password
```

---

### 🔍 Step 2: Post-Deployment Testing

#### 1️⃣ Get Private IP of vm-app

```bash
az vm show \
  --resource-group rg-flow-lab \
  --name vm-app \
  --show-details \
  --query privateIps -o tsv
```

#### 2️⃣ SSH into vm-web

```bash
az vm ssh --name vm-web --resource-group rg-flow-lab
```

#### 3️⃣ Attempt SSH to vm-app (Expected to Fail)

```bash
ssh azureuser@<vm-app-private-ip>
```

You should see a timeout or connection denied — verifying NSG is blocking the traffic.

---

### 📦 Step 3: Enable Flow Logs in Network Watcher (Manual or Scripted)

- Open Azure Portal > Network Watcher > NSG Flow Logs
- Select NSG `nsg-app`
- Enable logging
  - Destination: Create or select a Storage Account
  - Link to Log Analytics workspace: `flowlog-law`
- (Optional) Enable **Traffic Analytics** with 10-minute interval

---

### 📂 Step 4: Inspect Flow Logs (Optional)

Navigate to the Storage Account container or use Traffic Analytics to:
- Review JSON logs showing `deny` actions
- Confirm the flow from `vm-web (10.100.1.x)` to `vm-app (10.100.2.x:22)` was blocked

---

### 🧪 Step 5: Analyze Flow Logs with KQL in Log Analytics (Optional)

**Goal:** Validate denied SSH traffic is visible in flow logs via KQL.

> ⚠️ Prerequisites:
> - Flow logs must be enabled and connected to a Log Analytics Workspace (`flowlog-law`)
> - Traffic Analytics is enabled in your Bicep or CLI deployment

#### 1️⃣ Open Log Analytics:
- Go to **Log Analytics Workspaces** in Azure Portal
- Open the workspace `flowlog-law`
- Select **Logs** (KQL query window)

#### 2️⃣ Run the KQL Query:
```kql
AzureNetworkAnalytics_CL
| where FlowType_s == "Blocked" and L4Protocol_s == "TCP" and Dport_s == "22"
| where Direction_s == "I" and SubType_s == "FlowLog"
| project TimeGenerated, SrcIP_s, DstIP_s, Dport_s, L4Protocol_s, FlowType_s, VM_s
| order by TimeGenerated desc
```

#### ✅ Expected Output:
A table showing denied SSH traffic from vm-web to vm-app:

| TimeGenerated       | SrcIP_s       | DstIP_s       | Dport_s | FlowType_s | VM_s    |
|---------------------|---------------|---------------|---------|------------|---------|
| 2025-06-19 12:02:10 | 10.100.1.4    | 10.100.2.5    | 22      | Blocked    | vm-web  |

---

🎯 You have now:
- Deployed infrastructure using Bicep and CLI
- Tested denied traffic flow
- Verified NSG enforcement
- Enabled and reviewed Flow Logs
- Analyzed logs with KQL in Log Analytics

✅ **Lab Complete**

