<#
.SYNOPSIS
  Import vSphere environment to a Royal Document
.DESCRIPTION
  Automatically creating a Royal TS document based on vSphere environment:
  importing virtual machines, hosts and vCenters, its folder structure and
  including IP address, description, some custom fields and more.
.INPUTS
  Required parameters like FileName, VITarget and Credential. Take a look in the docs.
.OUTPUTS
  Royal Document with imported data.
.PARAMETER VITarget
  The VITarget means the hostname/IP of either a standalone ESXi or vCenter to import the data from.
.PARAMETER FileName
  The filename the document, and when enabled the CSV files, will be exported. Specify without file extension!
.PARAMETER Credential
  Specify a credential object for authentication. You can use (Get-Credential) cmdlet herefor. If not provided, PowerCLI will try using the current user.
.PARAMETER DoCsvExport
  If parameter provided, the data will also be exported in the CSV format. Two seperated files: <FileName>_vms.csv and <FielName>_hosts.csv will be created.
.PARAMETER SkipDnsReverseLookup
  If parameter provided, the DNS Reverse Lookup will be skipped. Only use when it makes sense.
.PARAMETER ExcludeVCenters
  If parameter provided, all vCenters will be excluded and not imported in the Royal document. By default everything will be imported.
.PARAMETER ExcludeHosts
  If parameter provided, all hosts will be excluded and not imported in the Royal document. By default everything will be imported.
.PARAMETER ExcludeVMs
  If parameter provided, all virtual machines will be excluded and not imported in the Royal document. By default everything will be imported.
.PARAMETER UseCredentialsFromParent
  If parameter provided all created objects will inherit the credentials from the parent object. Making it easy to centrally managing/setting a credential object for all objects.
.EXAMPLE
  C:\PS> .\importVIEnvironmentIntoRTS.ps1 -FileName "servers" -VITarget "vcenter.domain.local" -DoCsvExport
.EXAMPLE
  C:\PS> .\importVIEnvironmentIntoRTS.ps1 -FileName "servers" -VITarget "vcenter01.domain.local","vcenter02.domain.local" -DoCsvExport
.EXAMPLE
  C:\PS> .\importVIEnvironmentIntoRTS.ps1 -FileName "servers" -VITarget "esxi01.domain.local","vcenter03.domain.local"
.EXAMPLE
  C:\PS> .\importVIEnvironmentIntoRTS.ps1 -FileName "servers" -VITarget "esxi01.domain.local" -ExcludeHosts -ExcludeVCenters
.EXAMPLE
  C:\PS> .\importVIEnvironmentIntoRTS.ps1 -FileName "servers" -VITarget "esxi01.domain.local" -ExcludeVMs
.NOTES
  Name:           importVIEnvironmentIntoRTS
  Version:        2.5.0
  Author:         Patrik Kernstock (pkern.at)
  Copyright:      (C) 2017-2018 Patrik Kernstock
  Creation Date:  October 10, 2017
  Modified Date:  May 7, 2019
  Changelog:      For exact script changelog please check out the git commits history at:
				  https://github.com/patschi/royalts-scripts/commits/master/importVIEnvironmentIntoRTS/importVIEnvironmentIntoRTS.ps1
  Disclaimer:     No guarantee for anything.
				  No kittens were harmed during the development.
  Support:        For support please check out the "Support" section in the README file here:
				  https://github.com/patschi/royalts-scripts/tree/master/importVIEnvironmentIntoRTS#support
.LINK
  https://github.com/patschi/royalts-scripts/commits/master/importVIEnvironmentIntoRTS/
#>

##############################
### MAGIC CODE STARTS HERE ###
##############################

## PARAMETERS
param(
	# VITarget (hostname/IP)
	[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
	[String[]] $VITarget,

	# Filename for export. Without file extension. Default: vmw_servers.
	[Parameter(Mandatory=$false)]
	[String] $FileName = "vmw_servers",

	# Credential object
	[Parameter(Mandatory=$false)]
	[System.Management.Automation.Credential()]
	[System.Management.Automation.PSCredential]
	$Credential,

	# Set if we want to export the data as CSV files. Default: False.
	[Parameter(Mandatory=$false)]
	[Switch] $DoCsvExport,

	# Setting if retrieving hostnames by doing reverse lookup of virtual machine IPs.
	# When skipped this will speed up import process a bit.
	[Parameter(Mandatory=$false)]
	[Switch] $SkipDnsReverseLookup,

	# Decide if we exclude vCenters
	[Parameter(Mandatory=$false)]
	[Switch] $ExcludeVCenters,

	# Decide if we exclude Hosts
	[Parameter(Mandatory=$false)]
	[Switch] $ExcludeHosts,

	# Decide if we exclude VMs
	[Parameter(Mandatory=$false)]
	[Switch] $ExcludeVMs,

	# Decide if we exclude VMs
	[Parameter(Mandatory=$false)]
	[Switch] $UseCredentialsFromParent
)

####################################
### ** THE MAGIC STARTS HERE! ** ###
####################################
##  DO NOT TOUCH ANYTHING BELOW!  ##
####################################

# Just flip the provided value of the parameter.
$SkipDnsReverseLookup = !$useDNSReverseLookup
# Define export document filename
$RoyalDocFileName = $FileName + ".rtsz"

# You can export the data as CSV as well
if ($DoCsvExport) {
	# Export VMs csv list
	$exportCsv_VMs_Status   = $true
	$exportCsv_VMs_File     = $FileName + "_vms.csv"
	# Export hosts csv list
	$exportCsv_Hosts_Status = $true
	$exportCsv_Hosts_File   = $FileName + "_hosts.csv"
}

# flag if connect to vCenter or ESXi, for debugging purposes (e.g. PS ISE testing)
$connectServer = $true

# LOAD MODULES
# load module: Royal TS.
if (Get-Module -ListAvailable RoyalDocument.PowerShell) {
	# Check if module is available, if so, load it. This is when module got installed through PSGallery.
	Import-Module RoyalDocument.PowerShell

} else {
	# If not, we try the legacy way.
	$psModulePaths = @()
	$psModulePaths += Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'Royal TS V5\RoyalDocument.PowerShell.dll'
	$psModulePaths += Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'code4ward.net\Royal TS V4\RoyalDocument.PowerShell.dll'
	foreach ($psModulePath in $psModulePaths) {
		if (Test-Path $psModulePath) {
			Import-Module $psModulePath
			break
		}
	}
}

if (!(Get-Module "RoyalDocument.PowerShell")) {
	Write-Output "Required RoyalDocument module not loaded. Please make sure you have either the PowerShell module"
	Write-Output "installed through PSGallery (recommended), or have an older Royal TS release installed which still"
	Write-Output "ships the PowerShell module with the installer. See more info at PSGallery site at:"
	Write-Output "https://www.powershellgallery.com/packages/RoyalDocument.PowerShell/"
	Write-Output "Installation using PSGallery: $ Install-Module -Name RoyalDocument.PowerShell"
	Write-Output "Aborting."
	exit
}

# load module: VMware PowerCLI.
if (!(Get-Module -ListAvailable "VMware.VimAutomation.Core")) {
	Write-Output "Required VMware module not installed. See installation instruction at:"
	Write-Output "https://blogs.vmware.com/PowerCLI/2017/04/powercli-install-process-powershell-gallery.html"
	Write-Output "Installation using PSGallery: $ Install-Module -Name VMware.PowerCLI"
	Write-Output "Aborting."
	exit
}

Import-Module -Name VMware.VimAutomation.Core

# sanity checks
if (Test-Path $RoyalDocFileName) {
	Write-Output "Royal Document '$RoyalDocFileName' does already exist. Aborting."
	Write-Output "Delete or rename the file and run this script once again."
	Write-Output "Aborting."
	exit
}

# FUNCTIONS
# Function to recursively create folder hierarchy
function CreateRoyalFolderHierarchy()
{
	param(
		[string] $folderStructure,
		[string] $splitter = "/",
		$Folder,
		[string] $folderIcon,
		[bool] $inheritFromParent = $false
	)

	$currentFolder = $Folder
	$folderStructure = $folderStructure.trim($splitter)
	$folderStructure -split $splitter | ForEach-Object {
		$folder = $_
		$existingFolder = Get-RoyalObject -Folder $currentFolder -Name $folder -Type RoyalFolder
		if ($existingFolder) {
			Write-Verbose "Folder $folder already exists - using it"
			$currentFolder = $existingFolder
		} else {
			# create folder
			Write-Verbose "Folder $folder does not exist - creating it"
			$newFolder = New-RoyalObject -Folder $currentFolder -Name $folder -Type RoyalFolder
			# define folderIcon
			if ($folderIcon) {
				Set-RoyalObjectValue -Object $newFolder -Property CustomImageName -Value $folderIcon | Out-Null
			}
			# inherit from parent or not
			if ($inheritFromParent -eq $true) {
				Set-RoyalObjectValue -Object $newFolder -Property ManagementEndpointFromParent -Value $true | Out-Null
				Set-RoyalObjectValue -Object $newFolder -Property SecureGatewayFromParent -Value $true | Out-Null
			}
			# check if we want to inherit credentials from parent...
			if ($UseCredentialsFromParent) {
				# here CredentialFromParent is by default $false, so no need to force-set it here. This is the recommended way setting this option.
				Set-RoyalObjectValue -Object $newFolder -Property CredentialMode -Value 1 | Out-Null
				Set-RoyalObjectValue -Object $newFolder -Property CredentialFromParent -Value $true | Out-Null
			}
			$currentFolder = $newFolder
		}
	}
	return $currentFolder
}

# Function to get the full path with a defined splitter
function GetFullPath()
{
	param(
		$vm,
		[string] $splitter = "/"
	)

	$folder = $vm.ExtensionData
	# if Get-View object was specified, this is null. So we can use $vm to get the needed Get-View data.
	if (!$folder) {
		$folder = $vm;
	}
	while ($folder.Parent) {
		$folder = Get-View -Server $VIConnection $folder.Parent
		#Write-Host ($folder | Format-List | Out-String)
		#if ($folder.ChildType -contains "Folder" -and $folder.ChildType -notcontains "Datacenter" -and $folder.Name -notcontains "vm") {
		if ($folder.ChildType -notcontains "Datacenter" -and $folder.Name -notcontains "vm") {
			$path = $folder.Name + $splitter + $path
		}
	}
	$path = $path.toString().Trim($splitter)
	return $path
}

# Speed things up. for debugging purposes.
#$useDNSReverseLookup = $false
#$connectServer = $false

# CONNECT
Write-Output -Verbose "+ Retrieving data..."
$RoyalDocUserName = $false
# Connect to server
if ($connectServer) {

	Write-Output -Verbose "Connecting to vCenter $VITarget..."

	# Connect to destination
	# Ensure we can handle multiple VI connections at once. Usually on by default...
	Set-PowerCLIConfiguration -DefaultVIServerMode Multiple -Scope Session -Confirm:$false | Out-Null
	# check if we have any credentials provided we can use
	if ($Credential) {
		# yes, provided. so we use it.
		$VIConnection = Connect-VIServer -Server $VITarget -Credential $Credential -NotDefault
	} else {
		# nope. So we let PowerCLI trying to get the current session credentials.
		$VIConnection = Connect-VIServer -Server $VITarget -NotDefault
	}

	# check if the connection worked.
	if ($VIConnection.Length -le 0) {
		Write-Error "Could not connect to at least one endpoint of specified targets. Aborting."
		exit
	}

	# Get the current username. Used when creating or modifing objects within the document.
	$RoyalDocUserName = $VIConnection[0].User

	# RETRIEVE VIRTUAL MACHINES
	if (!$ExcludeVMs) {
		Write-Output -Verbose "Retrieving VM list..."
		$vms = Get-View -Server $VIConnection -ViewType VirtualMachine -Filter @{"Config.Template"="False"} | Sort-Object -Property Name | Select-Object `
			@{N="UUID"; E={$_.Summary.Config.Uuid}},`
			@{N="Name"; E={$_.Summary.Config.Name}},`
			@{N="Folder"; E={GetFullPath -VM $_}},`
			@{N="GuestId"; E={$_.Summary.Config.GuestId}},`
			@{N="GuestFamily"; E={$_.Guest.GuestFamily}},`
			@{N="GuestFullName"; E={$_.Summary.Config.GuestFullName}},`
			@{N="DnsName"; E={$_.Guest.Hostname}},`
			@{N="IpAddress"; E={($_.Guest.Net.IpAddress[0])}},`
			@{N="Notes"; E={$_.Config.Annotation}},`
			@{N="powerState"; E={$_.Runtime.powerState}}
	}

	# RETRIEVE HOSTS
	if (!$ExcludeHosts) {
		Write-Output -Verbose "Retrieving hosts list..."
		$hosts = Get-View -Server $VIConnection -ViewType Hostsystem | Sort-Object -Property Name | Select-Object `
			@{N="UUID"; E={$_.Summary.Hardware.Uuid}},`
			@{N="Name"; E={$_.Name}},`
			@{N="IpAddress"; E={($_.Config.Network.Vnic | Where-Object {$_.Device -eq "vmk0"}).Spec.Ip.IpAddress}},`
			@{N="Type"; E={$_.Hardware.SystemInfo.Vendor + " " + $_.Hardware.SystemInfo.Model}},`
			@{N="Cluster"; E={
				# get parent...
				$parent = Get-View -Id $_.Parent -Property Name, Parent
				# check if parent is cluster. If not, it's probably a host folder. So we search one step further.
				while($parent -isnot [VMware.Vim.ClusterComputeResource]) {
					# next try... is it now a cluster?
					$parent = Get-View -Id $parent.Parent -Property Name, Parent
				}
				# finally return the name of the cluster. we got it.
				$parent.Name
			}}
	}

	# RETRIEVE CONNECTED VITARGETS
	if (!$ExcludeVCenters) {
		Write-Output -Verbose "Retrieving connected VI targets list..."
		$targets = $VIConnection | Select-Object `
			@{N="UUID"; E={$_.InstanceUuid}},`
			@{N="Host"; E={$_.ServiceUri.Host}},`
			@{N="ProductLine"; E={$_.ProductLine}},`
			@{N="Version"; E={$_.Version}},`
			@{N="Build"; E={$_.Build}}
	}

	# disconnecting
	Write-Output -Verbose "Disconnecting from vCenter $VITarget..."
	Disconnect-VIServer -Server $VIConnection -Confirm:$false
}

# CSV EXPORT
if ($exportCsv_VMs_Status -or $exportCsv_Hosts_Status) {
	Write-Host "+ Exporting CSV..."
	# export VMs as csv
	if ($exportCsv_VMs_Status -and $vms.Length -eq 0) {
		Write-Output -Verbose "Exporting CSV VMs file..."
		$vms | Export-CSV -Path $exportCsv_VMs_File -NoTypeInformation
	}

	# export VMs as csv
	if ($exportCsv_Hosts_Status -and $hosts.Length -eq 0) {
		Write-Output -Verbose "Exporting CSV hosts file..."
		$hosts | Export-CSV -Path $exportCsv_Hosts_File -NoTypeInformation
	}
}

# CREATE DOCUMENT
# if we do not know the username, we use any default one
if (!$RoyalDocUserName) {
	$RoyalDocUserName = "VI-Importer";
}

# create store (container for any documents)
$store = New-RoyalStore -UserName $RoyalDocUserName
# creating a temporary royal document
$doc = New-RoyalDocument -Store $store -Name "VMware Virtual Machines Import" -FileName $RoyalDocFileName

Write-Host "+ Importing..."
# DOCUMENT IMPORT
# importing servers into royal document
if ($vms.Length -gt 0) {
	Write-Output -Verbose "- Importing vms..."
	$lastFolder = CreateRoyalFolderHierarchy -FolderStructure "Connections/Virtual Machines/" -Folder $doc -FolderIcon "/Flat/Hardware/Computers" -InheritFromParent $true
	ForEach ($server in $vms) {

		# skip servers which are not powered on, as we can not retrieve the IP address of the guest due to no running VMware tools
		if ($server.powerState -ne "poweredOn") {
			Write-Warning "Ignoring $($server.Name) as the machine is not powered on and IP address cannot be retrieved..."
			continue
		}

		# creating connection without IpAddress does not make that much sense. So we are checking it here.
		if (!$server.IpAddress) {
			Write-Warning "Ignoring $($server.Name) due to empty IP address..."
			continue
		}

		# import...
		Write-Output -Verbose "Importing $($server.Name)..."
		# get folder, create it recursively if it does not exist
		$lastFolder = CreateRoyalFolderHierarchy -FolderStructure ("Connections/Virtual Machines/" + $server.Folder) -Folder $doc -InheritFromParent $true

		# description: either dnsName or vmName
		if ($server.DnsName) {
			$description = $server.DnsName
		} else {
			$description = $server.Name
		}

		# add GuestFullName if possible to description
		if ($server.GuestFullName) {
			$description = $description + " (" + $server.GuestFullName + ")"
		}

		# check if we want to use rDNS
		if ($useDNSReverseLookup) {
			# Try to use reverse dns to get hostname of IP address
			# Check for failure of rDNS
			try {
				$ipAddr = [System.Net.Dns]::GetHostEntry($server.IpAddress).HostName
			} catch {
				# Failure: Fallback to IP address
				$ipAddr = $server.IpAddress
			}

		} else {
			$ipAddr = $server.IpAddress
		}

		# create object depending on osType
		if ($server.GuestId -like "windows*") {
			$newConnection = New-RoyalObject -Folder $lastFolder -Type RoyalRDSConnection -Name $server.Name
			$newConnection.Description = $description
			$newConnection.URI = $ipAddr
			$newConnection.Notes = $server.Notes
		} else {
			$newConnection = New-RoyalObject -Folder $lastFolder -Type RoyalSSHConnection -Name $server.Name
			$newConnection.Description = $description
			$newConnection.URI = $ipAddr
			$newConnection.Notes = $server.Notes
			$newConnection.InitialSendKeySequenceToServer = $true
		}
		$newConnection.ManagementEndpointFromParent = $true
		$newConnection.SecureGatewayFromParent = $true

		# using CustomField for now, CustomProperties not yet supported in PS-API
		$newConnection.CustomField1 = $server.UUID
		$newConnection.CustomField2 = $server.GuestFamily
	}

} else {
	Write-Host "- Importing vms... Skipped."
}

# importing hosts into royal document
if ($hosts.Length -gt 0) {
	Write-Output -Verbose "- Importing hosts..."
	$lastFolder = CreateRoyalFolderHierarchy -FolderStructure "Connections/Hosts/" -Folder $doc -FolderIcon "/Flat/Hardware/CPU" -InheritFromParent $true
	$hosts | ForEach-Object {
		$hostObj = $_

		Write-Output -Verbose "Importing $($hostObj.Name)..."

		$hostFolderName = $hostObj.Name
		if ($hostObj.Cluster) {
			$hostFolderName = $hostObj.Cluster + "/" + $hostObj.Name
		}
		# create folder recursively
		$lastFolder = CreateRoyalFolderHierarchy -FolderStructure ("Connections/Hosts/" + $hostFolderName) -Folder $doc -FolderIcon "/Flat/Hardware/Server" -InheritFromParent $true

		# check if we want to use rDNS
		if ($useDNSReverseLookup) {
			# Try to use reverse dns to get hostname of IP address
			# Check for failure of rDNS
			try {
				$ipAddr = [System.Net.Dns]::GetHostEntry($hostObj.IpAddress).HostName
			} catch {
				# Failure: Fallback to IP address
				$ipAddr = $hostObj.IpAddress
			}

		} else {
			$ipAddr = $hostObj.IpAddress
		}

		# create SSH connection
		$newConnection = New-RoyalObject -Folder $lastFolder -Type RoyalSSHConnection -Name ($hostObj.Name + " SSH")
		$newConnection.Description = $hostObj.Type
		$newConnection.URI = $ipAddr
		Set-RoyalObjectValue -Object $newConnection -Property SecureGatewayFromParent -Value $true | Out-Null
		# using CustomField for now, CustomProperties not yet supported in PS-API
		$newConnection.CustomField1 = $hostObj.UUID
		$newConnection.CustomField2 = $hostObj.Type

		# create WEB connection
		$newConnection = New-RoyalObject -Folder $lastFolder -Type RoyalWebConnection -Name ($hostObj.Name + " Web")
		$newConnection.URI = "https://" + $ipAddr + "/"
		Set-RoyalObjectValue -Object $newConnection -Property SecureGatewayFromParent -Value $true | Out-Null
		# using CustomField for now, CustomProperties not yet supported in PS-API
		$newConnection.CustomField1 = $hostObj.UUID
		$newConnection.CustomField2 = $hostObj.Type

		# create VMware connection
		$newConnection = New-RoyalObject -Folder $lastFolder -Type RoyalVMwareConnection -Name $hostObj.Name
		$newConnection.Description = $hostObj.Type
		$newConnection.URI = $ipAddr
		Set-RoyalObjectValue -Object $newConnection -Property ManagementEndpointFromParent -Value $true | Out-Null
		Set-RoyalObjectValue -Object $newConnection -Property SecureGatewayFromParent -Value $true | Out-Null
		# using CustomField for now, CustomProperties not yet supported in PS-API
		$newConnection.CustomField1 = $hostObj.UUID
		$newConnection.CustomField2 = $hostObj.Type
	}

} else {
	Write-Host "- Importing hosts... Skipped."
}

# importing vCenter into document
if (@($targets).Count -gt 0) {
	Write-Output -Verbose "- Importing vCenter..."
	# create main vCenter root folder once
	$lastFolder = CreateRoyalFolderHierarchy -FolderStructure "Connections/vCenter/" -Folder $doc -FolderIcon "/Flat/Hardware/Storage" -InheritFromParent $true
	$imported_vcenter = 0

	$targets | ForEach-Object {
		$target = $_

		# Check if target is vCenter.
		# vpx == vCenter, embeddedEsx == ESXi.
		if ($target.ProductLine -ne "vpx") {
			return
		}

		# check if we want to use rDNS
		if ($useDNSReverseLookup) {
			# Try to use reverse dns to get hostname of IP address
			# Check for failure of rDNS
			try {
				$ipAddr = [System.Net.Dns]::GetHostEntry($target.Host).HostName
			} catch {
				# Failure: Fallback to IP address
				$ipAddr = $target.Host
			}

		} else {
			$ipAddr = $target.Host
		}

		Write-Output -Verbose "Importing vCenter $($ipAddr)..."

		# create folder recursively
		$lastFolder = CreateRoyalFolderHierarchy -FolderStructure ("Connections/vCenter/" + $ipAddr) -Folder $doc -FolderIcon "/Flat/Hardware/Screen Monitor" -InheritFromParent $true

		# create SSH connection
		$newConnection = New-RoyalObject -Folder $lastFolder -Type RoyalSSHConnection -Name "$($ipAddr) SSH"
		$newConnection.Description = "vCenter SSH"
		$newConnection.URI = $ipAddr
		Set-RoyalObjectValue -Object $newConnection -Property SecureGatewayFromParent -Value $true | Out-Null
		# using CustomField for now, CustomProperties not yet supported in PS-API
		$newConnection.CustomField1 = $target.UUID
		$newConnection.CustomField2 = $target.ProductLine

		# create VMware connection
		$newConnection = New-RoyalObject -Folder $lastFolder -Type RoyalVMwareConnection -Name "$($ipAddr)"
		$newConnection.Description = "vCenter Object"
		$newConnection.URI = $ipAddr
		Set-RoyalObjectValue -Object $newConnection -Property ManagementEndpointFromParent -Value $true | Out-Null
		Set-RoyalObjectValue -Object $newConnection -Property SecureGatewayFromParent -Value $true | Out-Null
		# using CustomField for now, CustomProperties not yet supported in PS-API
		$newConnection.CustomField1 = $target.UUID
		$newConnection.CustomField2 = $target.ProductLine

		# create WEB connection
		$newConnection = New-RoyalObject -Folder $lastFolder -Type RoyalWebConnection -Name "$($ipAddr) Web"
		$newConnection.Description = "vCenter Web"
		$newConnection.URI = "https://" + $ipAddr + "/"
		Set-RoyalObjectValue -Object $newConnection -Property SecureGatewayFromParent -Value $true | Out-Null
		# using CustomField for now, CustomProperties not yet supported in PS-API
		$newConnection.CustomField1 = $target.UUID
		$newConnection.CustomField2 = $target.ProductLine

		# create VAMI WEB connection
		$newConnection = New-RoyalObject -Folder $lastFolder -Type RoyalWebConnection -Name "$($ipAddr) VAMI Web"
		$newConnection.Description = "vCenter VAMI Web"
		$newConnection.URI = "https://" + $ipAddr + ":5480/"
		Set-RoyalObjectValue -Object $newConnection -Property SecureGatewayFromParent -Value $true | Out-Null
		# using CustomField for now, CustomProperties not yet supported in PS-API
		$newConnection.CustomField1 = $target.UUID
		$newConnection.CustomField2 = $target.ProductLine

		$imported_vcenter++;
	}

} else {
	Write-Output -Verbose "- Importing vCenters... Skipped."
}

# did we imported any vCenters?
if ($imported_vcenter -le 0) {
	Write-Output -Verbose "No vCenters were imported as we were not connected to any."
}

# FINISHING
Write-Output -Verbose "+ Finishing..."

# ICON STUFF
Write-Output -Verbose "Setting icons..."
# giving connections folder some love
$connectionsObject = CreateRoyalFolderHierarchy -FolderStructure "Connections/" -Folder $doc -FolderIcon "/Flat/Hardware/Computers" -InheritFromParent $true
Set-RoyalObjectValue -Object $connectionsObject -Property CustomImageName -Value "/Flat/Software/Tree" | Out-Null

# setting connections>datacenter icon
# check if lastFolder is Datacenter folder-object (which means the lastFolder is directly below Connections folder)
$vmsFolderObject = Get-RoyalObject -Folder $connectionsObject -Type RoyalFolder -Name "Virtual Machines"
if ($vmsFolderObject) {
	Get-RoyalObject -Folder $vmsFolderObject -Type RoyalFolder -Name "*" | ForEach-Object {
		if ($_.ParentID -eq $vmsFolderObject.ID) {
			Set-RoyalObjectValue -Object $_ -Property CustomImageName -Value "/Flat/Network/Cloud" | Out-Null
		}
	}
}

# WRITE DOCUMENT
Write-Output -Verbose "Writing Royal Document $RoyalDocFileName..."
Out-RoyalDocument -Document $doc -FileName $RoyalDocFileName

# ...and we're done.
Write-Output -Verbose "+ Done."

# FIN
