# Create an External vSwitch
New-VMSwitch -Name external -NetAdapterName "Local Area Connection 2"

# Create an Internal vSwitch
New-VMSwitch -Name internal -SwitchType internal -Notes 'Internal VMs only'

# Create a Private vSwitch
New-VMSwitch -Name private -SwitchType Private

# Configure a single VLAN
Set-VMNetworkAdapterVlan -VMName EyVM01 -VMNetworkAdapterName "External" -Access -VlanId 10

#Configure trunking
Set-VMNetworkAdapterVlan -VMName EYVM01-Trunk -AllowedVlanIdList 1-100 -NativeVlanId 10

# Configure the minimum Bandwidth
Set-VMNetworkAdapter -VMName EYVM1 -MinimumBandwidth 1000000

# Create a vSwitch with Default Flow Minimum Bandwidth Weight
New-VMSwitch -Name external -NetAdapterName "Local Area Connection 2" –DefaultFlowMinimumBandwidthWeight

#Create a SET
New-VMSwitch -Name SwitchSET -NetAdapterName "NIC 1","NIC 2" -EnableEmbeddedTeaming $true -ManagementOS $True

# Add/Remove network adapters to SET
Set-VMSwitchTeam -Name SwitchSET -NetAdapterName "NIC 1","NIC 3"

# Converged Network
Add-VMNetworkAdapter -ManagementOS -Name "Management" -SwitchName "External" MinimumBandwidthWeight 10
Add-VMNetworkAdapter -ManagementOS -Name "Live Migration" -SwitchName "External" MinimumBandwidthWeight 25
Add-VMNetworkAdapter -ManagementOS -Name "VMs" -SwitchName "External" MinimumBandwidthWeight 50
Add-VMNetworkAdapter -ManagementOS -Name "Cluster" -SwitchName "External" MinimumBandwidthWeight 15 

# Configure DCB
Turn on DCB
Install-WindowsFeature Data-Center-Bridging
# Set a policy for SMB-Direct 
New-NetQosPolicy "SMB" -NetDirectPortMatchCondition 445 -PriorityValue8021Action 3
# Turn on Flow Control for SMB
Enable-NetQosFlowControl  -Priority 3
# Make sure flow control is off for other traffic
Disable-NetQosFlowControl  -Priority 0,1,2,4,5,6,7
# Apply policy to the target adapters
Enable-NetAdapterQos  -InterfaceAlias "SLOT 2*"
# Give SMB Direct 30% of the bandwidth minimum
New-NetQosTrafficClass "SMB"  -Priority 3  -BandwidthPercentage 30 

#Configure RDMA on vNIC 
Add-VMNetworkAdapter -SwitchName SETswitch -Name SMB_1 -managementOS
Add-VMNetworkAdapter -SwitchName SETswitch -Name SMB_2 -managementOS
Enable-NetAdapterRDMA "vEthernet (SMB_1)","vEthernet (SMB_2)"

#Mec the mapping between vNIC and pNIC
Set-VMNetworkAdapterTeamMapping –VMNetworkAdapterName SMB_1 –ManagementOS –PhysicalNetAdapterName NIC 1
Set-VMNetworkAdapterTeamMapping –VMNetworkAdapterName SMB_2 –ManagementOS –PhysicalNetAdapterName NIC 2

#Enable DHCPGuard
Get-VM | Set-VMNetworkAdapter -DhcpGuard On




