# scb-akkodis-course
SCB Azure Training Series by Akkodis. Includes slide decks and lab guides for six sessions covering IAM, threat detection, secure networking, data protection, app migration, and compliance in Azure. Designed for hands-on learning in enterprise cloud environments.

---
## Session 1 – Demo  
**Secure Storage Access Using ARM Template and RFC 1918 IP Strategy**

This hands-on demo walks participants through deploying a secure logging architecture using private networking and storage isolation.  
The deployment aligns with enterprise cloud security standards by enforcing private access via RFC 1918 ranges and private endpoints.

### 🔧 Lab Steps Overview

#### 1. Setup
- Prepare Visual Studio Code or Azure Cloud Shell  
- Ensure Azure CLI is installed and authenticated  
- Create a new resource group in the target region  

#### 2. Deploy Infrastructure
- Define an ARM template with a custom VNet and AppSubnet  
- Deploy an Azure Storage account with public access disabled  
- Provision a Private Endpoint for the storage account  
- Create and link a Private DNS Zone for internal name resolution  

#### 3. Test and Validate
- Confirm DNS resolution returns a private IP address  
- Attempt access from outside the network to ensure it fails  
- Deploy a Linux VM in the subnet and test access to the storage privately  
- Optionally, enforce internet isolation using NSG outbound rules  

### ✅ Expected Outcome
- A secure VNet using `10.50.0.0/16` with subnetting  
- A storage account that’s only accessible over the private network  
- DNS correctly resolving via `privatelink.blob.core.windows.net`  
- Full validation that no public access is allowed, and internal routing works

---
👨‍💻 Author: Georges Bou Ghantous

* Azure Training Series by Akkodis, featuring hands-on labs and demos across six sessions on IAM, threat detection, secure networking, data protection, app migration, and compliance in Azure.
---
