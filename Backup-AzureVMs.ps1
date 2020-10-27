workflow Backup-AzureVMs
{
    # Author:  Ziggy Nemeth
    # Version: 1.1  10/4/15   
    
    <#
    .SYNOPSIS
       Back up the VHDs of a virtual machine or cloud service.
    
    .DESCRIPTION
       Back up the VHD OS and data disks of a specific virtual machine, or of all virtual
       machines in a cloud service. The backed up VHDs are saved to a new container in 
       the existing storage account of the virtual machine.
    
    .PARAMETER SubscriptionName
       The case-sensitive name of the Azure subscription which contains the virtual machine(s) 
       to be backed up.
       Source: The runbook will prompt to enter this mandatory parameter.
       
    .PARAMETER TargetName
       The name of the virtual machine or cloud service which will be backed up.
       Source: The runbook will prompt to enter this mandatory parameter.
       
    .PARAMETER TargetType
       The type of the TargetName parameter. This value can be "Cloud" or "VM".
       Source: The runbook will prompt to enter this mandatory parameter.
       
    .PARAMETER WhatIfModeInput
       Enable or disable WhatIf testing mode. This value can be "True" or "False".
       If set to True, the runbook will not perform actions against the storage
       account, i.e. creating containers or backing up VHD blobs.
       Source: The runbook will prompt to enter this mandatory parameter.
       
    .PARAMETER AzureAdmin
       The credentials to perform VHD backup tasks (eg. a subscription co-administrator).
       An Azure Active Directory (AAD) account is recommended for this credential as
       opposed to a Microsoft Account (MSA).
       Source: Azure Automation credential asset
    
    .PARAMETER BackupContainer
       The prefix which will be used when creating the backup storage container.
       Azure storage container naming guidelines must be adhered to.
       Source: Azure Automation variable asset
    
    .EXAMPLE
       Configure the AzureAdmin credential asset with the username and password, 
       for example a username of backupuser@azureaccount.onmicrosoft.com.
       Configure the BackupContainer credential asset with the prefix string,
       for example "vhds-backup".
    
    .EXAMPLE
       When prompted, enter the mandatory parameters for the runbook. For example:
       SubscriptionName: Development
       TargetName: devcloudsvc
       TargetType: Cloud
       WhatIfModeInput: False
    
    .NOTES
       This runbook uses Write-Output throughout to provide useful formatted logging
       history.
       This runbook copies VHD blobs regardless of whether the virtual machine is
       running or not. Note that backing up VHD disks of running virtual machines
       may result in expected behaviour or data loss or corruption.
       
    #>
   
    param (
        [parameter(Mandatory=$True)]
        [string]
        $SubscriptionName = "Enter case-sensitive subscription name",

        [parameter(Mandatory=$True)]
        [string]
        $TargetName = "Enter Cloud Service or Virtual Machine name",     

        [parameter(Mandatory=$True)]
        [string]
        $TargetType = "Enter Cloud or VM",     
        
        [parameter(Mandatory=$True)]
        [string]
        $WhatIfModeInput = "False"
    )
    
    Write-Output "INFO: Started Backup-AzureVMs runbook"
    $ErrorActionPreference = "Stop"
    $VerbosePreference = "SilentlyContinue"
    
    If (($WhatIfModeInput.ToUpper() -like "FALSE") -or ($WhatIfModeInput.ToUpper() -like "NO")) {
        $WhatIfMode = $False
    } 
    Else { 
        $WhatIfMode = $True
    }
    If ($WhatIfMode) { Write-Output "INFO:    Test only - running in WhatIf mode" }
    Else             { Write-Output "INFO:    Running in production mode"}
   
    Write-Output "INFO: Authenticating to Azure..."
    $Cred = Get-AutomationPSCredential -Name 'azureadmin'
    $Authn = Add-AzureAccount -Credential $Cred
    Write-Output "INFO:    Authenticated as $($Authn.Id)"
    If (!$Authn) {
        Write-Output "ERROR: Could not authenticate to Azure. Check the AzureAdmin credential asset."
        Write-Error -Message $_.Message -ErrorAction Stop
    }

    $BackupContainer = Get-AutomationVariable -Name 'BackupContainer'
    If (!$BackupContainer) {
        Write-Output "ERROR: BackupContainer variable asset not found or is null."
        Write-Error -Message $_.Message -ErrorAction Stop
    }
            
    InlineScript{ 

        $CreatedContainer = $False

        Write-Output "INFO: Selecting subscription: $Using:SubscriptionName"
        Select-AzureSubscription -SubscriptionName $Using:SubscriptionName
        ($Sub = Get-AzureSubscription | Where {$_.IsCurrent -eq $True}) | Out-Null
        Write-Output "INFO:    $($Sub.SubscriptionName), IsCurrent:$($Sub.IsCurrent)"
    
        If ($Using:TargetType -like "*Cloud*") {
            Write-Output "INFO: Cloud Service entered"
            ($TargetVMs = Get-AzureVM -ServiceName $Using:TargetName | ForEach {$_.Name}) | Out-Null # Get all VM names in the Cloud Service
            Write-Output "INFO:    Found VMs in Cloud Service:"
            Write-Output "INFO:       $($TargetVMs)"
        } 
        If ($Using:TargetType -like "*VM*") {
            $TargetVMs = $Using:TargetName # Target is a single VM
            Write-Output "INFO: Single VM target entered."
         } 
    
      ForEach ($TargetVM in $TargetVMs) {
    
        Write-Output "INFO:    Checking for VM $TargetVM..."
        ($VM = Get-AzureVM | Where {$_.Name -eq $TargetVM}) | Out-Null
        If ($VM) {
            Write-Output "INFO:          $($VM.DeploymentName), $($VM.HostName): $($VM.Status), $($VM.PowerState)"
        }
        Else {
            Write-Output "ERROR: VM not found or is null."
            Write-Error -Message $_.Message -ErrorAction Stop
        }
    
        Write-Output "INFO:    Getting Azure Disks for VM $TargetVM..."
        $VMDisks = Get-AzureDisk | Where {$_.AttachedTo -like "*$TargetVM*"}
        $VMDisks | ForEach {
           Write-Output "INFO:       $($_.DiskName), $($_.MediaLink)"
        }

        $StorageAccount = ($VMDisks[0].MediaLink.Host).Split(".",2)[0]
        Write-Output "INFO:    First disk's storage account is: $StorageAccount"
        Write-Output "INFO:    Selecting storage account..."
        Set-AzureSubscription -SubscriptionName $Using:SubscriptionName -CurrentStorageAccountName $StorageAccount
        ($StorageAccount = Get-AzureSubscription | Where {$_.CurrentStorageAccountName -ne $Null}) | Out-Null
        Write-Output "INFO:       $($StorageAccount.CurrentStorageAccountName), IsCurrent:$($StorageAccount.IsCurrent)"
      
        If (!$CreatedContainer) {
           $ContainerName = "$($Using:BackupContainer)-$(Get-Date -format yyyyMMddHHmm)"
           Write-Output "INFO:    Creating container $ContainerName..."
           If (!$Using:WhatIfMode) {
              New-AzureStorageContainer -Name $ContainerName -Permission Off | Out-Null
              Write-Output "INFO:       Created container."
              $CreatedContainer = $True # Only create target container once per runbook execution
           }
        }
            
        $VMDisks | ForEach {
            $VhdBaseName = ($_.MediaLink.Segments[2]).split(".",2)[0]
            $TimeStamp = Get-Date -format yyyyMMddHHmm
            Write-Output "INFO:          Backing up $VhdBaseName with suffix $TimeStamp..."
            $SourceAbsoluteUri = $_.MediaLink.AbsoluteUri
            $DestBlobName = $VhdBaseName + "_" + $TimeStamp + ".vhd"
            If (!$WhatIfMode) {
               Start-AzureStorageBlobCopy -AbsoluteUri $SourceAbsoluteUri -DestBlob $DestBlobName -DestContainer $ContainerName | Out-Null # Out-Null to avoid output errors
            }
        }
        Write-Output "INFO: Completed VM $TargetVM."
      }
      Write-Output "INFO: Completed all VMs."
    } #end of InlineScript
    Write-Output "INFO: Completed runbook."
} #end of workflow