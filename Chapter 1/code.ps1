#get the windows edition
get-windowsedition –online

# Get edition available for upgrading
Get-WindowsEdition –online –target

# Upgrade to datacenter core edition
dism.exe /online /Set-Edition:ServerDatacenterCor /AcceptEula /ProductKey:<ProductKey>

#Activate and uninstall license
slmgr –upk #(this uninstalls the current product key)
slmgr –ipk <key> #(including dashes)

# Create VSwitch with multiple NIC
New-VMSwitch -Name SW-1G -NetAdapterName "Local Area Connection 2"

#Create a vSwitch with one NIC
New-VMSwitch -Name SW-1G -NetAdapterName "Local Area Connection" -AllowManagementOS $true

#Set default path for Hyper-V
Set-VMHOST –computername localhost –virtualharddiskpath 'D:\VMs'
Set-VMHOST –computername localhost –virtualmachinepath 'D:\VMs'

#Create a new VM Gen1
New-VM

#Create a new VM gen2
New-VM –Generation 2

# Create a VM with specific path and memory
New-VM –Name VM01 –Path C:\VM01 –Memorystartupbytes 1024MB

#Create a VHD
New-VHD -Path C:\vms\vm01\vm01_c.vhdx -SizeBytes 60GB -Dynamic

# Add VHD to VM
Add-VMHardDiskDrive -VMName VM01 -Path C:\vms\vm01\vm01_c.vhdx

# Add vNIC to VM
Add-VMNetworkAdapter -vmname "VM01" -switchname "external"

#Start the VM
Start-VM –Name VM01