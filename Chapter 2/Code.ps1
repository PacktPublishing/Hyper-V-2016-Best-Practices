#Rename network adapters
Rename-NetAdapter -Name "Ethernet" -NewName "Host"
Rename-NetAdapter -Name "Ethernet 2" -NewName "LiveMig"
Rename-NetAdapter -Name "Ethernet 3" -NewName "VMs"
Rename-NetAdapter -Name "Ethernet 4" -NewName "Cluster"
Rename-NetAdapter -Name "Ethernet 5" -NewName "Storage"

#Install Failover Clustering roles
Install-WindowsFeature -Name Failover-Clustering -IncludeManagementTools –Computername pyhyv01, Elani-tyHV02

# Test Cluster
Install-WindowsFeature -Name Failover-Clustering `
                       -IncludeManagementTools `
                       -Computername pyhyv01, pyhyv02



# Create the cluster
New-Cluster -Name CN=ElanityClu1,OU=Servers,DC=cloud,DC=local `
            -Node pyhyv01, pyhyv02 `
            -StaticAddress 192.168.1.49

# Install MPIO
Install-WindowsFeature -Name Multipath-IO–Computername Pyhyv01, Pyhyv02

# Set the Quorum on a disk
Set-ClusterQuorum -NodeAndDiskMajority "Cluster Disk 2"

#Set the Quorum on a file share
Set-ClusterQuorum -NodeAndFileShareMajority \\ElanityFile01\Share01

# Set a Cloud Witness Quorum
Set-ClusterQuorum -CloudWitness `
                  -AccountName StorageAccountName> `
                  -AccessKey <AccessKey> 

#Configure AD for Live-Migration with Kerberos
$Host = "pyhyv02"
$Domain = "Cloud.local"
Get-ADComputer pyhyv01 | Set-ADObject -Add @{"msDS-AllowedToDelegateTo"="Microsoft Virtual System Migration Service/$Host.$Domain", "cifs/$Host.$Domain","Microsoft Virtual System Migration Service/$Host", "cifs/$Host"}

#Configure Hyper-V to use Kerberos for Live-Migration
Enable-VMMigration –Computername pyhyv01, pyhyv02
Set-VMHost –Computername pyhyv01, pyhyv02 `
           –VirtualMachineMigrationAuthenticationType Kerberos

#Change live-migration settings
Set-VMHost -Computername pyhyv01, pyhyv02 `
           -MaximumVirtualMachineMigrations 4 `
           –MaximumStorageMigrations 4 `
           –VirtualMachineMigrationPerformanceOption SMBTransport

#Configure cluster network
(Get-ClusterNetwork -Name "Management ").Role = 3
Set-VMMigrationNework 192.168.10.* –Priority 4.000
(Get-ClusterNetwork -Name "Cluster").Role = 1
(Get-ClusterNetwork –Name "Cluster").Metric = 3.000
(Get-ClusterNetwork -Name "Storage").Role = 0

# Move a VM to another node
Move-VM "VM01" Pyhyv02

#Suspend a node
Suspend-ClusterNode -Name Pyhyv01 -Target Pyhyv02 –Drain

#VM Start Ordering
New-ClusterGroupSet -Name SQLServers
New-ClusterGroupSet -Name VMMServers
New-ClusterGroupSet -Name OMGServers

Set-ClusterGroupSet -Name SQLServers -ReadySetting OS_Heartbeat
Set-ClusterGroupSet -Name VMMServers -ReadySetting OS_Heartbeat
Set-ClusterGroupSet -Name OMGServers -ReadySetting OS_Heartbeat

Add-ClusterGroupSetDependency -Name VMMServers -ProviderSet SQLServers
Add-ClusterGroupSetDependency -Name OMGServers -ProviderSet SQLServers

Add-ClusterGroupToSet -Name VMVMM01 -Group VMMServers
Add-ClusterGroupToSet -Name VMVMM02 -Group VMMServers
Add-ClusterGroupToSet -Name VMSQL01 -Group SQLServers
Add-ClusterGroupToSet -Name VMSQL02 -Group SQLServers
Add-ClusterGroupToSet -Name VMOMG01 -Group OMGServers

#Configure Node Fairness
(Get-Cluster).AutoBalancerLevel = 3
(Get-Cluster).AutoBalancerMode = 1

#Cluster Aware Updating
Add-CauClusterRole -ClusterName Cluster-Hyv01 -Force -CauPluginName Microsoft.WindowsUpdatePlugin -MaxRetriesPerNode 3 -CauPluginArguments @{ 'IncludeRecommendedUpdates' = 'True' } -StartDate "5/6/2014 3:00:00 AM" -DaysOfWeek 4 -WeeksOfMonth @(3) –verbose

#AntiAffanity rules
(Get-ClusterGroup ERP-VM1).AntiAffinityClassNames = "GuestCluster-ERP1"
(Get-ClusterGroup ERP-VM2).AntiAffinityClassNames = "GuestClusterERP1"

Get-ClusterGroup VM1 | fl anti*

# Configure guest cluster
(Get-Cluster).CrossSubnetThreshold = 25
(Get-Cluster).SameSubnetThreshold = 25



