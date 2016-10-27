# run setup of Windows Server 2016 in upgrade mode
Setup.exe /auto:upgrade

#Import a single VM
Import-VM -Path 'D:\VMs\EyVM01\Virtual Machines\2D5EECDA-8ECC-4FFC-ACEE-66DAB72C8754.xml'

# Import all VM
Get-ChildItem d:\VMs -Recurse -Filter "Virtual Machines" | %{Get-ChildItem $_.FullName -Filter *.xml} | %{import-vm $_.FullName -Register}

# Convert a VHD in VHDX
Convert-VHD –Path d:\VMs\testvhd.vhd –DestinationPath d:\VMs\testvhdx.vhdx

#Export a VM
Export-VM –Name VM –Path D:\

#Export all VMs
Get-VM | Export-VM –Path D:\

# Move the cluster to native w2016 mode
Update-ClusterFunctionalLevel

# Show non present device in device manager
set DEVMGR_SHOW_NONPRESENT_DEVICES=1
devmgmt.msc 

