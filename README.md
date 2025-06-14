# scb-akkodis-course
SCB Azure Training Series by Akkodis. Includes slide decks and lab guides for six sessions covering IAM, threat detection, secure networking, data protection, app migration, and compliance in Azure. Designed for hands-on learning in enterprise cloud environments.

---
## Session 1 – Demo  
**Secure Storage Access Using ARM Template and RFC 1918 IP Strategy**

This hands-on demo walks participants through deploying a secure logging architecture using private networking and storage isolation.  
The deployment aligns with enterprise cloud security standards by enforcing private access via RFC 1918 ranges and private endpoints.

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

---
👨‍💻 Author: Georges Bou Ghantous

* Azure Training Series by Akkodis, featuring hands-on labs and demos across six sessions on IAM, threat detection, secure networking, data protection, app migration, and compliance in Azure.
---
