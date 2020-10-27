Backup all disks for a single Azure VM or for all VMs in a Cloud Service
========================================================================

            

** **


** **


**

 
**The runbook's contents are displayed above.




 




**Description
**
Using Azure Automation, back up the VHD OS and data disks of a specific virtual machine, or of all virtual machines in a cloud service. The backed up VHDs are saved to a new container in the existing storage account of the virtual
 machine.



**Requirements
**


Azure Automation credential asset 'AzureAdmin' - this account must have permissions to perform VHD backup tasks (for example a subscription co-administrator). An Auzre Active Directory (AAD) account is recommended, as opposed to
 a Microsoft Account (MSA).


Azure Automation variable asset 'BackupContainer' - this string is the prefix used when created the backup storage container. The Azure storage container naming guidelines must be adhered to.

        
    
TechNet gallery is retiring! This script was migrated from TechNet script center to GitHub by Microsoft Azure Automation product group. All the Script Center fields like Rating, RatingCount and DownloadCount have been carried over to Github as-is for the migrated scripts only. Note : The Script Center fields will not be applicable for the new repositories created in Github & hence those fields will not show up for new Github repositories.
