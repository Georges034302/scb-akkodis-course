# scb-akkodis-course
SCB Azure Training Series by Akkodis. Includes slide decks and lab guides for six sessions covering IAM, threat detection, secure networking, data protection, app migration, and compliance in Azure. Designed for hands-on learning in enterprise cloud environments.

---
<details>
<summary><strong>Session 1 – Demo</strong> (click to expand/hide)</summary>

### 🧪 Hands-On Lab: Secure Storage Access Using ARM Template and RFC 1918 IP Strategy

#### 🏷️ Lab Title
Deploy a Secure Logging Architecture with Private Endpoint and RFC 1918 IP Strategy Using ARM JSON

#### 🎯 Lab Objective
Deploy a logging subnet and storage account using RFC 1918 IP address space, and integrate it with a Private Endpoint and Private DNS Zone to enforce internal-only access — following best practice cloud security architecture.

#### ✅ Lab Scenario
A centralized logging application resides within AppSubnet. This app must write logs to an Azure Storage account, which must not be accessible over the internet.

### 🔧 Lab Steps Overview

| Setup Step | Description                                      |
|------------|--------------------------------------------------|
| 1          | Create the Resource Group                        |
| 2          | Create the ARM Template                          |

| Deploy Step | Description                                     |
|-------------|-------------------------------------------------|
| 1           | Deploy the ARM Template                         |
| 2           | Create the Private Endpoint                     |
| 3           | Create and Link Private DNS Zone                |

| Test Step   | Description                                     |
|-------------|-------------------------------------------------|
| 1           | Verify DNS Resolution (from inside the VNet)    |
| 2           | Confirm Public Access Blocked                   |
| 3           | (Optional) Create a Test VM in the VNet         |
| 4           | (Optional) SSH into the Test VM                 |
| 5           | (Optional) Test DNS and Storage Access from VM  |
| 6           | (Optional) Test Internet Blocking via NSG       |

| Expected Outcome | Description                                                      |
|------------------|------------------------------------------------------------------|
| 1                | Storage account is only accessible privately                     |
| 2                | DNS resolves to private IP inside the VNet                       |
| 3                | Public access is blocked as expected                             |
| 4                | Private endpoint and DNS zone are validated                      |
| 5                | A secure VNet using `10.50.0.0/16` with subnetting               |
| 6                | A storage account that’s only accessible over the private network|
| 7                | DNS correctly resolving via `privatelink.blob.core.windows.net`  |
| 8                | Full validation that no public access is allowed, and internal routing works

</details>

<details>
<summary><strong>Session 2 – Demo</strong> (click to expand/hide)</summary>

### 🧪 Hands-On Lab: Sentinel Lab – Key Vault Detection

#### 🏷️ Lab Title
Detect and Respond to Suspicious Access Patterns in Azure Key Vault Using Microsoft Sentinel

#### 🎯 Lab Objective
Simulate and detect excessive secret access by a privileged identity, trigger a Microsoft Sentinel analytics rule, and automate the response using a Logic App to disable the account and notify the SOC team.

#### ✅ Lab Scenario
A privileged user retrieves secrets from Azure Key Vault more frequently than expected, indicating possible insider threat or credential misuse.

## 🔧 Lab Steps Overview

| Setup Step | Description                                      |
| ---------- | ------------------------------------------------ |
| 1          | Create Resource Group and Key Vault              |
| 2          | Assign Key Vault Contributor role to a test user |
| 3          | Enable diagnostic logging to Log Analytics       |

| Detection Step | Description                                  |
| -------------- | -------------------------------------------- |
| 1              | Simulate 10 secret retrievals using CLI loop |
| 2              | Author Sentinel Analytics Rule using KQL     |

| Response Step | Description                                 |
| ------------- | ------------------------------------------- |
| 1             | Create Logic App Playbook for auto-response |
| 2             | Connect playbook to analytics rule          |

| Expected Outcome | Description                                                |
| ---------------- | ---------------------------------------------------------- |
| 1                | Sentinel incident created upon detection                   |
| 2                | User account automatically disabled via Graph API          |
| 3                | SOC notified via Teams                                     |
| 4                | Event archived and metrics visible in Workbooks/Dashboards |
| 5                | End-to-end audit-traceable response workflow confirmed     |

</details>

<details>
<summary><strong>Session 3 – Demo</strong> (click to expand/hide)</summary>

### 🧪 Hands-On Lab: NSG Flow Visibility Lab – Monitor and Block Intra-VNet Traffic

#### 🏷️ Lab Title
Simulate and monitor denied traffic within Azure Virtual Networks using Network Security Groups (NSGs) and Flow Logs

#### 🎯 Lab Objective
Deploy a 2-tier segmented network with enforced NSG rules to block unauthorized east-west traffic. Use Network Watcher to monitor and validate traffic visibility and rule effectiveness.

#### ✅ Lab Scenario
A frontend VM (`vm-web`) is placed in a web subnet and attempts SSH access to a backend VM (`vm-app`) in a secure subnet. An NSG rule blocks the connection, and flow logs are used to confirm denied traffic events.

---

### 🔧 Lab Steps Overview

| Setup Step | Description                                         |
|------------|-----------------------------------------------------|
| 1          | Deploy infrastructure using Bicep or CLI            |
| 2          | Apply NSG to deny SSH from web-subnet to app-subnet |
| 3          | Enable Network Watcher in the region                |

| Validation Step | Description                                    |
|-----------------|------------------------------------------------|
| 1               | Attempt SSH from vm-web to vm-app              |
| 2               | Confirm connection is denied due to NSG rule   |
| 3               | Analyze NSG Flow Logs for denied traffic       |

| Expected Outcome | Description                                   |
|------------------|-----------------------------------------------|
| 1                | East-west SSH blocked by explicit NSG rule    |
| 2                | Flow logs show denied TCP/22 traffic          |
| 3                | Demonstrates intra-VNet traffic visibility    |

</details>

<details>
<summary><strong>Session 4 - Demo</strong> (click to expand/hide)</summary>

<!-- No data yet -->

</details>

<details>
<summary><strong>Session 5 - Demo</strong> (click to expand/hide)</summary>

<!-- No data yet -->

</details>

<details>
<summary><strong>Session 6 - Demo</strong> (click to expand/hide)</summary>

<!-- No data yet -->

</details>

---
👨‍💻 Author: Georges Bou Ghantous

* Azure Training Series by Akkodis, featuring hands-on labs and demos across six sessions on IAM, threat detection, secure networking, data protection, app migration, and compliance in Azure.
---
