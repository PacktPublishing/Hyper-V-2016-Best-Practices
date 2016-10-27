#Create a Storage Spaces with tiering
$PhysicalDisks = Get-PhysicalDisk -CanPool $True
New-StoragePool -FriendlyName VMStore01 `
                -StorageSubsystemFriendlyName "Storage Spaces*" `
                -PhysicalDisks $PhysicalDisks

$tier_ssd = New-StorageTier -StoragePoolFriendlyName VMStore01 `
                            -FriendlyName SSD_TIER `
                            -MediaType SSD 
  
$tier_hdd = New-StorageTier -StoragePoolFriendlyName VMStore01 `
                            -FriendlyName HDD_TIER `
                            -MediaType HDD

#Set the tiering to manual
Set-FileStorageTier -FilePath d:\Fastfiles\fast.file `
                    -DesiredStorageTier $tier_ssd

# ----- Disaggregated storage ------

#install role and create the cluster
Install-WindowsFeature FS-FileServer, Failover-Clustering, Data-Center-Bridging, RSAT-Clustering-Mgmt, RSAT-Clustering-Powershell -Restart
Test-Cluster FS01, FS02, FS03, FS04 -Include "Storage Spaces Direct", Inventory,Network,"System Configuration"
New-Cluster –Name FSCluster `
            –Node FS01, FS02, FS03, FS04 –NoStorage `
            –StaticAddress 10.10.0.164

# COnfigure the Quorum
Set-ClusterQuorum -CloudWitness `
                  -Cluster FSCluster `
                  -AccountName MyAzureAccount -AccessKey <AccessKey>


# Configure the networks
(Get-ClusterNetwork -Cluster FSCluster -Name "Cluster Network 1").Name="Management"
(Get-ClusterNetwork -Cluster FSCluster -Name "Cluster Network 2").Name="Storage"
(Get-ClusterNetwork -Cluster FSCluster -Name "Cluster Network 3").Name="Cluster"

#Enable Storage Spaces Direct
cluster = New-CimSession -ComputerName FSCluster
Enable-ClusterS2D -CimSession $cluster

# Create a volume
New-Volume -StoragePoolFriendlyName S2D* `
           -FriendlyName VMStorage `
           -NumberOfColumns 2 `
           -PhysicalDiskRedundancy 1 `
           -FileSystem CSVFS_REFS `
           –Size 50GB

# Deploy Scale-Out File Server
Add-ClusterScaleOutFileServerRole -Cluster FSCluster -Name SOFS

# Create a share and set permission
$SharePath = "c:\ClusterStorage\Volume01\VMSTO01”
md $SharePath
New-SmbShare -Name VMSTO01 -Path $SharePath -FullAccess FS01$, FS02$, FS03$, FS04$
Set-SmbPathAcl -ShareName $ShareName

# ----- Disaggregated storage ------
Install-WindowsFeature Hyper-V, FS-FileServer, Failover-Clustering, Data-Center-Bridging, RSAT-Clustering-Mgmt, RSAT-Clustering-Powershell, RSAT-Hyper-V-Tools -Restart
New-Cluster –Name HVCluster `
            –Node HV01, HV02, HV03, HV04 `
            –NoStorage `
            –StaticAddress 10.10.0.164

#Quorum witness
Set-ClusterQuorum -CloudWitness `
                  -Cluster FSCluster `
                  -AccountName MyAzureAccount `
                  -AccessKey <AccessKey>

# Rename Network
(Get-ClusterNetwork -Cluster HVCluster -Name "Cluster Network 1").Name="Management"
(Get-ClusterNetwork -Cluster HVCluster -Name "Cluster Network 2").Name="Storage"
(Get-ClusterNetwork -Cluster HVCluster -Name "Cluster Network 3").Name="Cluster"
(Get-ClusterNetwork -Cluster HVCluster -Name "Cluster Network 4").Name="LiveMigration”

# Enable S2D
$cluster = New-CimSession -ComputerName FSCluster
Enable-ClusterS2D -CimSession $cluster

#Create a CSV
New-Volume -StoragePoolFriendlyName S2D* `
           -FriendlyName VMStorage `
           -NumberOfColumns 2 `
           -PhysicalDiskRedundancy 1 `
           -FileSystem CSVFS_REFS `
           –Size 50GB

#MultiResilient Virtual Disk
New-StorageTier -StoragePoolFriendlyName S2D* -FriendlyName "ColdTier" -MediaType HDD
New-StorageTier -StoragePoolFriendlyName S2D* -FriendlyName "HotTier" -MediaType SSD
New-Volume -StoragePoolFriendlyName S2D* `
           -FriendlyName VMStorage02 `
           -FileSystem CSVFS_REFS `
           -StorageTierFriendlyName HotTier, ColdTier `
           -StorageTierSizes 100GB, 900GB

# Convert VHD to VHDX
Convert-VHD -Path d:\VM01.vhd -DestinationPath d:\VM01.vhdx

#convert VHD to VHDX with dynamic hard disk
Convert-VHD -Path d:\VM01.vhd `
            -DestinationPath d:\VM01.vhdx `
            -VHDType dynamic

#convert to VHDX from pass-through disk
New-VHD -Path "D:\VMS\Converted.VHDX" -Dynamic –SourceDisk 5

# Gather CSV information
Get-ClusterSharedVolume

# Change the cluster block size
(Get-Cluster).BlockCacheSize = 512

# Create checkpoint
Checkpoint-VM -Name Test -SnapshotName Snapshot1

# Deduplication
ddpeval.exe <Path>
Install-windowsFeature FS-Data-Deduplication
Enable-DeDupVolume D:
Set-DedupVolume -Volume D: -MinimumFileAgeDays 5
Start-DedupJob D: -Type Optimization
New-dedupschedule -Name "Dedup01" -Type Optimization -Days Sat, Wed -Start 23:00 -DurationHours 10
Enable-DedupVolume C:\ClusterStorage\Volume1 –UsageType HyperV

#Storage QOS
$CimSession = New-CimSession -ComputerName Cluster-HyperV
New-StorageQosPolicy -Name bronze -MinimumIops 50 -MaximumIops 150 -CimSession $CimSession
Get-VM -Name VM01 -ComputerName Cluster-HyperV |
Get-VMHardDiskDrive |
Set-VMHardDiskDrive -QoSPolicyID (Get-StorageQosPolicy -Name Bronze -CimSession $CimSession).PolicyId 

# MPIO
Enable-WindowsOptionalFeature –Online –FeatureName MultiPathIO
Enable-MSDSMAutomaticClaim -BusType iSCSI
Enable-MSDSMAutomaticClaim -BusType SAS
Set-MSDSMGlobalDefaultLoadBalancePolicy -Policy RR
Set-MPIOSetting -NewDiskTimeout 60

# iSCSI target
Add-WindowsFeature -Name FS-iSCSITarget-Server
Add-WindowsFeature -Name iSCSITarget-VSS-VDS
New-IscsiVirtualDisk -Path d:\VHD\LUN1.vhdx -Size 60GB
New-IscsiServerTarget -TargetName Target1 -InitiatorId IPAddress:192.168.1.240,IPAddress:192.168.1.241
Add-IscsiVirtualDiskTargetMapping -TargetName target1 Path d:\VHD\LUN1.vhdx –Lun 10
Connect-IscsiTarget -NodeAddress <targetIQN>