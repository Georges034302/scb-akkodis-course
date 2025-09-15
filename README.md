# scb-akkodis-course
SCB Azure Training Series by Akkodis. Includes slide decks and lab guides for six sessions covering IAM, threat detection, secure networking, data protection, app migration, and compliance in Azure. Designed for hands-on learning in enterprise cloud environments.

---
<details>
<summary><strong>Session 1 – Demo</strong> (click to expand/hide)</summary>

### 🧪 [Enforce Required Tags with Azure Policy, Bicep & GitHub Actions](session1/session1-enforce-tags.md)
- **Objective:** Require an `owner` tag on every Azure resource using Azure Policy as code, Bicep for assignment, and GitHub Actions for deployment.
- **Topics:** Policy as code, Bicep, OIDC, GitHub Actions, tag governance.

### 🧪 [Restrict VM SKUs with Azure Policy](session1/session1-allowed-vms.md)
- **Objective:** Restrict allowed VM SKUs in a subscription using Azure Policy.
- **Topics:** Policy definition, assignment, compliance validation.

### 🧪 [Entra RBAC & MFA Enforcement](session1/session1-entra-rbac-mfa.md)
- **Objective:** Configure Entra ID (Azure AD) RBAC and enforce MFA for privileged roles.
- **Topics:** Entra ID, RBAC, MFA, role assignment, security best practices.

</details>

<details>
<summary><strong>Session 2 – Demo</strong> (click to expand/hide)</summary>

### 🧪 [Sentinel Lab – Key Vault Detection](session2/session2_demo.md)
- **Objective:** Detect and respond to suspicious access patterns in Azure Key Vault using Microsoft Sentinel and Logic Apps.
- **Topics:** Sentinel analytics, KQL, Logic Apps, incident response, Key Vault monitoring.

</details>

<details>
<summary><strong>Session 3 – Demo</strong> (click to expand/hide)</summary>

### 🧪 [Secure Logging Architecture with Private Endpoint](session3/session3-secure-logging.md)
- **Objective:** Deploy a secure logging architecture using ARM/Bicep, private endpoints, and private DNS.
- **Topics:** Storage security, private networking, DNS, ARM/Bicep automation.

### 🧪 [NSG Flow Logs – Monitor and Block Intra-VNet Traffic](session3/session3_nsg-flow-logs.md)
- **Objective:** Monitor and block intra-VNet traffic using NSGs and Flow Logs.
- **Topics:** NSG rules, Network Watcher, flow log analysis, segmentation.

</details>

<details>
<summary><strong>Session 4 – Demo</strong> (click to expand/hide)</summary>

### 🧪 [Immutable Storage for Audit Compliance](session4/session4-demo.md)
- **Objective:** Configure immutable blob storage with protected append writes and legal hold using CLI and Portal.
- **Topics:** Storage immutability, WORM, compliance, legal hold, CLI automation.

</details>

<details>
<summary><strong>Session 5 – Demo</strong> (click to expand/hide)</summary>

### 🛠️ [Azure DMS Migration Demo – Azure SQL ➞ Azure SQL](session5/session5-demo.md)
- **Objective:** Perform an online migration from Azure SQL Server to Azure SQL Server using Azure Database Migration Service (DMS).
- **Topics:** Database migration, DMS, automation, validation, SQL.

</details>

<details>
<summary><strong>Session 6 – Demo</strong> (click to expand/hide)</summary>

### 🧪 [Azure Policy & Blueprints for Enterprise Governance](session6/session6-demo.md)
- **Objective:** Automate and enforce cloud governance with Azure Policy and Blueprints.
- **Topics:** Policy definitions, initiatives, blueprints, compliance, RBAC, ARM/Bicep.

</details>

<details>
<summary><strong>Session 7 – Demo</strong> (click to expand/hide)</summary>

### 🧰 Common Environment Setup & Cleanup
- **Script:** [`session7/env.sh`](session7/env.sh)

### 🧪 [Lift & Shift Migration Lab](session7/liftshift/lift-and-shift.md)
- **Objective:** Simulate a lift-and-shift (rehost) migration by capturing a Linux VM, creating a snapshot and managed disk, and deploying a new VM from that disk to represent the migrated workload.
- **Topics:** Lift & Shift (Rehost) migration, VM snapshot, managed disks, disk cloning, SSH validation, mapping to Azure Migrate workflow.

### 🧪 [On-Premises to Azure Migration Lab](session7/on-prem_azure/on-prem-to-azure.md)
- **Objective:** Demonstrate a basic migration scenario from on-premises to Azure using Azure Site Recovery.
- **Topics:** Recovery Services Vault, agent registration, replication, test failover, cleanup.

### 🧪 [Azure to Azure Migration Lab](session7/azure_migration/azure-to-azure.md)
- **Objective:** Move a VM between Azure regions using image capture and deployment.
- **Topics:** VM deallocation, generalization, image creation, cross-region image copy, VM deployment from image.

### 🧪 [AWS to Azure Migration Lab](session7/aws_azure/aws-to-azure.md)
- **Objective:** Demonstrate a basic migration scenario from AWS to Azure using Azure Migrate.
- **Topics:** Azure Migrate project, appliance setup, AWS discovery, replication, migration, cleanup.

</details>

---

#### 🧑‍🏫 Author: Georges Bou Ghantous
<sub><i>This repository delivers enterprise-ready Azure training labs and demos developed by Georges Bou Ghantous for SCB, covering cloud identity, secure networking, threat detection, data protection, migration, and governance in real-world banking scenarios.</i></sub>
