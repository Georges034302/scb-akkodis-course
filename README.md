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
| 8                | Full validation that no public access is allowed, and internal routing
</details>

<details>
<summary><strong>Session 3 - Demo</strong> (click to expand/hide)</summary>

<!-- No data yet -->

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
