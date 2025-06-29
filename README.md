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

### 🧪 Hands-On Lab: Immutable Storage for Audit Compliance

#### 🏷️ Lab Title
Configure Immutable Blob Storage with Protected Append Writes and Legal Hold Using Azure CLI and Portal

#### 🎯 Lab Objective
Implement enterprise-grade immutable storage in Azure Blob to retain critical logs for 7 years in WORM (Write Once Read Many) mode, using CLI and Portal.

#### ✅ Lab Scenario
You are tasked with ensuring security audit logs are immutable and verifiable for a 7-year compliance period.

A storage account and container are deployed with a time-based WORM policy (2555 days), protected append writes, and (optionally) a legal hold.

---

### 🔧 Lab Steps Overview

| Setup Step | Description                                         |
|------------|-----------------------------------------------------|
| 1          | Login to Azure CLI                                  |
| 2          | Create resource group and storage account           |
| 3          | Create blob container                               |
| 4          | Set immutability policy (WORM, append writes)       |
| 5          | Upload sample log file                              |
| 6          | Lock immutability policy                            |
| 7          | (Optional) Apply legal hold                         |

| Validation Step | Description                                    |
|-----------------|------------------------------------------------|
| 1               | Attempt to delete blob (should fail)           |
| 2               | Check immutability policy status               |
| 3               | Confirm append writes are allowed              |
| 4               | (Optional) Check legal hold status             |

| Expected Outcome | Description                                   |
|------------------|-----------------------------------------------|
| 1                | Blob container is immutable for 7 years       |
| 2                | Blob deletion is blocked by WORM policy       |
| 3                | Append writes succeed, but deletes/updates fail|
| 4                | Legal hold is visible and enforced             |

</details>

<details>
<summary><strong>Session 5 - Demo</strong> (click to expand/hide)</summary>

### 🧪 Hands-On Lab: Azure DMS Migration – SQL Server (Docker) to Azure SQL Managed Instance

#### 🏷️ Lab Title
Online Migration from On-Premises SQL Server (Docker) to Azure SQL Managed Instance using Azure Database Migration Service (DMS)

#### 🎯 Lab Objective
Simulate a real-world **online migration** from a local SQL Server (running in Docker) to Azure SQL Managed Instance (MI) using Azure DMS, with all steps performed via Azure CLI and JSON configuration files.

#### ✅ Lab Scenario
You are tasked with migrating a production SQL Server database to Azure SQL MI. The source is simulated using a Docker container. The migration must be automated, auditable, and validated using CLI and SQL queries.

---

### 🔧 Lab Steps Overview

| Setup Step | Description                                                      |
|------------|------------------------------------------------------------------|
| 1          | Prepare Docker SQL Server as the source                          |
| 2          | Define source, target, and database options JSON config files    |
| 3          | Create Azure DMS instance, migration project, and migration task |
| 4          | Monitor migration and validate results in Azure SQL MI           |

| Validation Step | Description                                    |
|-----------------|------------------------------------------------|
| 1               | Connect to Azure SQL MI and validate data      |
| 2               | Confirm schema and row count match source      |
| 3               | Review DMS migration status and logs           |

| Expected Outcome | Description                                   |
|------------------|-----------------------------------------------|
| 1                | Docker SQL Server simulates on-premises source|
| 2                | Azure SQL MI receives data via DMS migration  |
| 3                | CLI automates full workflow                   |
| 4                | Manual or scripted query confirms migration   |

</details>

<details>
<summary><strong>Session 6 - Demo</strong> (click to expand/hide)</summary>

### 🧪 Hands-On Lab: Azure Policy & Blueprints for Enterprise Governance

#### 🏷️ Lab Title
Automate and Enforce Cloud Governance with Azure Policy and Blueprints

#### 🎯 Lab Objective
Design and implement enterprise governance at scale using Azure Policy and Blueprints. Enforce compliance, resource consistency, and security standards across multiple subscriptions using policy definitions, initiatives, and blueprint assignments.

#### ✅ Lab Scenario
You are tasked with ensuring all Azure resources in your organization comply with security and operational standards. You will use Azure Policy to restrict resource types, enforce tagging, and require encryption. Blueprints will be used to deploy standardized environments with built-in compliance controls.

---

### 🔧 Lab Steps Overview

| Setup Step | Description                                                      |
|------------|------------------------------------------------------------------|
| 1          | Create a resource group for governance artifacts                 |
| 2          | Author and assign Azure Policy definitions (e.g., allowed SKUs, required tags, encryption) |
| 3          | Group policies into an initiative and assign to a subscription   |
| 4          | Create and publish an Azure Blueprint with artifacts (policies, RBAC, ARM templates) |
| 5          | Assign the blueprint to a subscription or management group       |

| Validation Step | Description                                    |
|-----------------|------------------------------------------------|
| 1               | Deploy resources and verify policy enforcement  |
| 2               | Attempt to create non-compliant resources      |
| 3               | Review compliance results in Azure Policy blade|
| 4               | Confirm blueprint assignment and artifact deployment |

| Expected Outcome | Description                                   |
|------------------|-----------------------------------------------|
| 1                | Non-compliant resources are denied or flagged |
| 2                | Required tags and settings are enforced       |
| 3                | Blueprint assignments deploy consistent environments |
| 4                | Compliance dashboard reflects policy status   |

</details>
