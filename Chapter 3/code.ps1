# Enable Hyper-V Replica
Set-VMReplicationServer -AllowedAuthenticationType kerberos `
                        -ReplicationEnabled 1

#Enable Hyper-V Replica on multiple Host
Set-VMReplicationServer -AllowedAuthenticationType kerberos `
                        -ReplicationEnabled 1 `
                        –ComputerName "Pyhyv01", "Pyhyv02" `
                        -DefaultStorageLocation "C:\ClusterStorage\Volume1\Hyper-V Replica"

# COnfigure Hyper-V replica to use certificate
Set-VMReplicationServer -ReplicationEnabled 1 `
                        -AllowedAuthenticationType Certificate `
                        -CertificateAuthenticationPort 8000 `
                        -CertificateThumbprint "0442C676C8726ADDD1CE029AFC20EB158490AFC8"

#Add the Hyper-V Replica broker
Add-ClusterServerRole -Name Replica-Broker –StaticAddress 192.168.1.5
Add-ClusterResource -Name "Virtual Machine Replication Broker" `
                    -Type "Virtual Machine Replication Broker" `
                    -Group Replica-Broker
Add-ClusterResourceDependency "Virtual Machine Replication Broker" Replica-Broker
Start-ClusterGroup Replica-Broker

# Enable firewall
get-clusternode | ForEach-Object  {Invoke-command -computername $_.name -scriptblock {Enable-Netfirewallrule -displayname "Hyper-V Replica HTTP Listener (TCP-In)"}}
get-clusternode | ForEach-Object  {Invoke-command -computername $_.name -scriptblock {Enable-Netfirewallrule -displayname "Hyper-V Replica HTTPS Listener (TCP-In)"}}

#Configure incoming replication
Set-VMReplicationServer -AllowedAuthenticationType kerberos -ReplicationEnabled 1 –ComputerName "Pyhyv01", "Pyhyv02" -DefaultStorageLocation "C:\ClusterStorage\Volume1\Hyper-V Replica"- ReplicationAllowedFromAnyServer 0
New-VMReplicationAuthorizationEntry -AllowedPrimaryServer Pyhyv01.int.homecloud.net -ReplicaStorageLocation C:\ClusterStorage\Volume1\ –TrustGroup EYGroup01 –ComputerName Pyhyv02.int.homecloud.net

#Enable VM Replication
Set-VMReplication –VMName VM01 `
                  –ReplicaServerName pyhyv02.int.homecloud.net `
                  –ReplicaServerPort 80

# Start VM Replication
Start-VMInitialReplication –VMName VM01

# With compression
Start-VMInitialReplication –VMName VM01 –CompressionEnabled 1

#With other parameters
Start-VMInitialReplication –VMName VM01 –CompressionEnabled 1 -InitialReplicationStartTime 5/1/2014 7:00 AM –RecoveryHistory 24 -ReplicationFrequencySec 30 -VSSSnapshotFrequencyHour 4
Set-VMReplication –VMName VM01 –ReplicaServerName Py-hyv02.int.homecloud.net –ReplicaServerPort 80 -RecoveryHistory 24 -ReplicationFrequencySec 30 -VSSSnapshotFrequencyHour 4
Start-VMInitialReplication –VMName VM01 –CompressionEnabled 1 -InitialReplicationStartTime 5/1/2014 7:00 AM

#Configure Hyper-V Replica
$HVSource = "Pyhyv01"
$HVReplica = "Pyhyv02"
$Port = 80
$HVdisabld = get-vm -ComputerName $HVSource | where {$_.replicationstate -eq 'disabled' }
foreach ($VM in $HVdisabld) {
 enable-VMReplication $VM $Replica $Port $Auth
Set-VMReplication -VMName $VM.name  -ReplicaServerName $HVReplica -ReplicaServerPort $Port -AuthenticationType kerberos -CompressionEnabled $true -RecoveryHistory 0 -computername $HVSource
Start-VMInitialReplication $VM.name  -ComputerName $HVSource

#Hyper-V Replica testing and failover
Stop-VM –VMName EyVM1 –ComputerName Pyhyv01
Start-VMFailover –VMName VM01 –ComputerName Pyhyv01 –Prepare
Start-VMFailover –VMName VM01 –ComputerName Pyhyv02 –as Test
Set-VMReplication -VMName  VM01 -ComputerName Pyhyv02  –Reverse

# Configure Failover IP
Set-VMNetworkAdapterFailoverConfiguration VM01 -IPv4Address 192.168.1.1 `
                                               -IPv4SubnetMask 255.255.255.0 `
                                               -IPv4DefaultGateway 192.168.1.254

#Change the vSwitch 
Set-VMNetworkAdapter VM01 -TestReplicaSwitchName 'vSwitchTest01'

#Install Storage Replica
Install-WindowsFeature Storage-Replica, Failover-Clustering `
                       -IncludeManagementTools `
                       -ComputerName HV01, HV02, HV03, HV04 -Restart

#Grant access
Grant-SRAccess -ComputerName hv01 -Cluster hyperv-toulouse
Grant-SRAccess -ComputerName hv03 -Cluster hyperv-lyon

#Enable Storage Replica
New-SRPartnership -SourceComputerName Hyperv-Lyon `
                  -SourceRGName VMGroup01 `
                  -SourceVolumeName C:\ClusterStorage\volume1 `
                  -SourceLogVolumeName L: `
                  -DestinationCOmputerName HyperV-Toulouse `
                  -DestinationRGName VMGroup02 `
                  -DestinationVolumeName C:\ClusterStorage\Volume1 `
                  -DestinationLogVolumeName L:

#Remove Storage Replica
Remove-SRPartnership -DestinationComputerName HyperV-Toulouse `
                     -SourceComputerName Hyper-V-Lyon `
                     -SourceRGName VMGroup01 `
                     -DestinationRGName VMGroup02 `
                     -IgnoreRemovalFail
Remove-SRGroup -ComputerName HyperV-Toulouse -Name VMGroup02

#Run backup
wbadmin start backup –backupTarget:d:–hyperv:VM01 -force
wbadmin get versions –backupTarget:d:
wbadmin start recover–version:08/18/2014-22:01 –itemType:hyperv –items:VM01–backuptarget:d:

# Install Azure Backup agent
C:\Program Files\Microsoft Azure Back-up\DPM\DPM\ProtectionAgents\RA\11.0.50.0\amd64\DPMAgentInstaller_x64.exe

#Connect Azure Backup Agent to Azure Backup Server
C:\Program Files\Microsoft Data Protection Manag-er\DPM\bin\SetDPMServer -DPMServerName <MyAzureBackupServer>