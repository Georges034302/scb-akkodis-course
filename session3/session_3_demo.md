## 🧪 Lab Title: NSG Flow Visibility Lab – Monitor and Block Intra-VNet Traffic

---

### ✅ Prerequisites:

- Azure Subscription with Contributor or Owner access
- Azure CLI installed and authenticated
- Log Analytics Workspace and Storage Account (optional for diagnostics)

---

## 📘 Step-by-Step Lab Instructions

---

### 🔹 Option A: Deploy Infrastructure Using Bicep

**Goal:** Provision all resources using Bicep for repeatability and accuracy

1. Save the following to a file named `nsg_flow_lab.bicep`

```bicep
param location string = 'australiaeast'
param adminUsername string = 'azureuser'

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-flow-lab'
  location: location
}

resource vnet 'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name: 'vnet-demo'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.100.0.0/16'
      ]
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
          destinationAddressPrefix: '*'
          sourcePortRange: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

module vmweb 'br/public:vm-simple:1.0.0' = {
  name: 'vmWebModule'
  params: {
    name: 'vm-web'
    adminUsername: adminUsername
    subnetId: vnet.properties.subnets[0].id
    location: location
    osType: 'Linux'
  }
}

module vmapp 'br/public:vm-simple:1.0.0' = {
  name: 'vmAppModule'
  params: {
    name: 'vm-app'
    adminUsername: adminUsername
    subnetId: vnet.properties.subnets[1].id
    location: location
    osType: 'Linux'
    nsgId: nsg.id
  }
}
```

2. Deploy the Bicep template:

```bash
az deployment sub create \
  --location australiaeast \
  --template-file ./nsg_flow_lab.bicep
```

---

### 🔹 Option B: Deploy Infrastructure Using Azure CLI

**Goal:** Provision equivalent infrastructure using CLI commands

```bash
az group create \
  --name rg-flow-lab \
  --location australiaeast

az network vnet create \
  --resource-group rg-flow-lab \
  --name vnet-demo \
  --address-prefix 10.100.0.0/16 \
  --subnet-name web-subnet \
  --subnet-prefix 10.100.1.0/24

az network vnet subnet create \
  --resource-group rg-flow-lab \
  --vnet-name vnet-demo \
  --name app-subnet \
  --address-prefix 10.100.2.0/24

az vm create \
  --resource-group rg-flow-lab \
  --name vm-web \
  --image UbuntuLTS \
  --admin-username azureuser \
  --generate-ssh-keys \
  --vnet-name vnet-demo \
  --subnet web-subnet

az vm create \
  --resource-group rg-flow-lab \
  --name vm-app \
  --image UbuntuLTS \
  --admin-username azureuser \
  --generate-ssh-keys \
  --vnet-name vnet-demo \
  --subnet app-subnet

az network nsg create \
  --resource-group rg-flow-lab \
  --name nsg-app

az network nsg rule create \
  --resource-group rg-flow-lab \
  --nsg-name nsg-app \
  --name deny-web-to-app \
  --priority 100 \
  --direction Inbound \
  --access Deny \
  --protocol Tcp \
  --source-address-prefix 10.100.1.0/24 \
  --source-port-range '*' \
  --destination-address-prefix '*' \
  --destination-port-range 22

az network nic update \
  --resource-group rg-flow-lab \
  --name vm-appVMNic \
  --network-security-group nsg-app
```

---

### 🔹 Step 2: Enable Network Watcher and Flow Logs

**Goal:** Visualize denied traffic

```bash
az network watcher configure \
  --locations australiaeast \
  --resource-group rg-flow-lab \
  --enabled true

# Enable flow logs manually or using CLI if storage and workspace available
```

---

### 🔹 Step 3: Simulate Denied Traffic

**Goal:** Test NSG effectiveness and log visibility

```bash
az vm show \
  --resource-group rg-flow-lab \
  --name vm-app \
  --show-details \
  --query privateIps -o tsv

az vm ssh --name vm-web --resource-group rg-flow-lab

# Inside the SSH session:
ssh azureuser@10.100.2.X  # Replace X with the actual address of vm-app
```

> 🛑 SSH will fail — as intended by the NSG rule.

---

## ✅ Success Criteria

| **Check**                              | **Expected Result**                   |
| -------------------------------------- | ------------------------------------- |
| Subnets and VMs deployed               | Resources exist and reachable         |
| NSG rule prevents SSH Web ➝ App        | SSH connection fails due to deny rule |
| Network Watcher enabled                | Region shows as monitored             |
| Flow logs/analytics visible (if setup) | Denied connections logged             |

---

