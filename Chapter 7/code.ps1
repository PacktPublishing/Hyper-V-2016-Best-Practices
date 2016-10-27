# Change power scheme to high performance
POWERCFG.EXE /S SCHEME_MIN

# Change power scheme to balance
POWERCFG.EXE /S SCHEME_BALANCED

# Check D-VMQ
Get-NetAdapterVmq –Name NICName

# Check vRSS
Enable-NetAdapterRSS –Name NICName

# Run a ping to try Jumbo Frame
ping -f -l 8500 192.168.1.10

# Disable IPv6
New-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\" -Name "DisabledComponents" -Value 0xffffffff -PropertyType "DWord"

#Disable ODX
Set-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem -Name "FilterSupportedFeaturesMode" -Value 1

#Deploy a VDI farm:
New-RDVirtualDesktopDeployment -ConnectionBroker VDI01.int.homecloud.net -WebAccessServer VDI02.int.homecloud.net -VirtualizationHost VDI03.int.homecloud.net

#Generalize image for a VM
C:\Windows\System32\Sysprep\Sysprep.exe /OOBe /Generalize /Shutdown /Mode:VM

#Create a Virtual Desktop Collection
New-RDVirtualDesktopCollection -CollectionName demoPool -PooledManaged `
 -VirtualDesktopTemplateName WinGold.vhdx `
 -VirtualDesktopTemplateHostServer VDI01 `
 -VirtualDesktopAllocation @{$Servername = 1} `
 -StorageType LocalStorage `
 -ConnectionBroker VDI02 `
 -VirtualDesktopNamePrefix msVDI

# Add GPU to a VM
Add-VMRemoteFx3dVideoAdapter –VMName VM01

#Set the resolution
SET-VMRemoteFx3dVideoAdapter –VMName VM01 –MaximumResolution 1920x1200



