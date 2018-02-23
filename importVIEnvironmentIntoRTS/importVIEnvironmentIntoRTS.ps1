<#
.SYNOPSIS
  Migrate vSphere environment to Royal Document
.DESCRIPTION
  Automatically creating a Royal TS document based on vSphere
  environment: importing virtual machines, hosts and vCenters,
  including IP address, description and more.
.INPUTS
  None
.OUTPUTS
  Basic output of current processed steps
.NOTES
  Version:        1.0
  Author:         Patrik Kernstock (pkern.at)
  Creation Date:  October 10, 2017
  Changelog:      1.0 First version.
  Disclaimer:     No guarantee for anything.
                  No kittens were harmed during the development.
#>

##################################
### CONFIGURATION
##################################
## CONFIGURATE ME!

### REQUIRED CONFIGURATION
## EXPORT
# Define document filename for export
$RoyalDocFileName = "vmw_servers.rtsz"

## API: vCenter/ESXi
# How to access the vCenter/ESXi host to query the data from
$vi_type     = "vcenter" # "esxi" or "vcenter"
$vi_ipaddr   = "vcenter.domain.local"
$vi_username = "DOMAIN\vSphereAdmin"
$vi_password = "<SPECIFY_PASSWORD_HERE>" # put the password just right into the variable
#$vi_password = cat (".\pw.txt") # as a alternative: create a pw.txt textfile within the same path as the script containing the plaintext password

### OPTIONAL CONFIGURATION
## OTHER SETTINGS
# Setting if retrieving hostnames by doing reverse lookup of virtual machine IPs.
# When enabled this will delay noticeable the import process.
$useDNSReverseLookup = $true
# Decide if you only want to add VMs with IP address set
$onlyAddVMWithIPAddress = $true

## OTHERS
# Path to the PowerShell module within the Royal TS installation directory (if it was installed elsewhere)
$RoyalPowerShellModule = "${env:ProgramFiles(x86)}\code4ward.net\Royal TS V4\RoyalDocument.PowerShell.dll"

## UNIMPORTANT / OPTIONAL
# Optional: you can export the data as CSV as well
# Export VMs csv list
$exportCsv_VMs_Status   = $false
$exportCsv_VMs_File     = "vmw_servers.csv"
# Export hosts csv list
$exportCsv_Hosts_Status = $false
$exportCsv_Hosts_File   = "vmw_hosts.csv"
# Define the username saved within object which is being created
$RoyalDocUserName       = $vi_username # "VI-Importer"

####################################
### ** THE MAGIC STARTS HERE! ** ###
####################################
##  DO NOT TOUCH ANYTHING BELOW!  ##
####################################

# variables
# flag if connect to vCenter or ESXi, for debugging purposes (e.g. PS ISE testing)
$connectServer = $true

# load modules: VMware and Royal TS.
Import-Module -Name VMware.VimAutomation.Core
Import-Module $RoyalPowerShellModule

# module loaded checks
if (!(Get-Module "VMware.VimAutomation.Core")) {
    Write-Output "VMware module not loaded. See more information at:"
    Write-Output "https://blogs.vmware.com/PowerCLI/2017/04/powercli-install-process-powershell-gallery.html"
    Write-Output "Aborting."
    exit
}

if (!(Get-Module "RoyalDocument.PowerShell")) {
    Write-Output "RoyalDocument module not loaded."
    Write-Output "Be sure Royal TS is installed and check if RoyalPowerShellModule is set."
    Write-Output "Aborting."
    exit
}

# sanity checks
if (Test-Path $RoyalDocFileName) {
    Write-Output "Royal Document '$RoyalDocFileName' does already exist. Aborting."
    Write-Output "Delete the file and run this script once again."
    Write-Output "Aborting."
    exit
}

if ([string]::IsNullOrEmpty($vi_password)) {
    Write-Output "VI-API password not specified."
    Write-Output "Aborting."
    exit
}

if ($vi_password -eq "<SPECIFY_PASSWORD_HERE>") {
    Write-Output "Please change the VI-API password within the script file."
    Write-Output "Aborting."
    exit
}

# convert password to secure string for being able to use it within PSCredential object
$vi_password = $vi_password | ConvertTo-SecureString -asPlainText -Force

# FUNCTIONS
# Function to recursively create folder hierarchy
function CreateRoyalFolderHierarchy()
{
    param(
        [string]$folderStructure,
        [string]$splitter = "/",
        $Folder,
        [string]$folderIcon,
        [bool]$inheritFromParent = $false
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
        [string]$splitter = "/"
    )

    $folder = $vm.ExtensionData
    while ($folder.Parent){
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

# speed things up. for debugging purposes.
#$useDNSReverseLookup = $false
#$connectServer = $false

# CONNECT
Write-Output -Verbose "+ Retrieving data..."
# connect to server
if ($connectServer) {

    Write-Output -Verbose "Connecting to vCenter $vi_ipaddr..."

    # load credentials object
    $credential = New-Object System.Management.Automation.PSCredential($vi_username, $vi_password)

    # connect to destination
    $VIConnection = Connect-VIServer -Server $vi_ipaddr -Credential $credential -NotDefault
    if ($VIConnection.IsConnected -eq $false) {
        Write-Error "Failed connecting to API endpoint. Aborting."
        exit
    }

    # RETRIEVE VIRTUAL MACHINES
    Write-Output -Verbose "Retrieving VM list..."
    $vms = Get-VM -Server $VIConnection | Sort-Object -Property Name | ForEach-Object {
        $_ | Select-Object Name, @{N="Folder"; E={GetFullPath -VM $_}}, @{N="GuestOS"; E={$_.guest.toString().Split(":")[1]}}, GuestId, @{N="DnsName"; E={$_.ExtensionData.Guest.Hostname}}, @{N="IPAddress";E={@($_.guest.IPAddress[0])}}, Notes
    }

    # RETRIEVE HOSTS
    Write-Output -Verbose "Retrieving hosts list..."
    $hosts = Get-VMHost -Server $VIConnection | Sort-Object -Property Name | Get-View | Select-Object Name, @{N=“IPAddress“;E={($_.Config.Network.Vnic | Where-Object {$_.Device -eq "vmk0"}).Spec.Ip.IpAddress}}, @{N=“Type“;E={$_.Hardware.SystemInfo.Vendor + “ “ + $_.Hardware.SystemInfo.Model}}

    # disconnecting
    Write-Output -Verbose "Disconnecting from vCenter $vi_ipaddr..."
    Disconnect-VIServer -Server $VIConnection -Confirm:$false
}

# CSV EXPORT
if ($exportCsv_VMs_Status -or $exportCsv_Hosts_Status) {
    Write-Host "+ Exporting CSV..."
    # export VMs as csv
    if ($exportCsv_VMs_Status) {
        Write-Output -Verbose "Exporting CSV VMs file..."
        $vms | Export-CSV -Path $exportCsv_VMs_File -NoTypeInformation
    }

    # export VMs as csv
    if ($exportCsv_Hosts_Status) {
        Write-Output -Verbose "Exporting CSV hosts file..."
        $hosts | Export-CSV -Path $exportCsv_Hosts_File -NoTypeInformation
    }
}

# CREATE DOCUMENT
# create store (container for any documents)
$store = New-RoyalStore -UserName $RoyalDocUserName
# creating a temporary royal document
$doc = New-RoyalDocument -Store $store -Name "VMware Virtual Machines Import" -FileName $RoyalDocFileName

# DOCUMENT IMPORT
# importing servers into royal document
Write-Host "+ Importing virtual machines..."
$lastFolder = CreateRoyalFolderHierarchy -FolderStructure "Connections/Virtual Machines/" -Folder $doc -FolderIcon "/Flat/Hardware/Computers" -InheritFromParent $true
ForEach ($server in $vms) {

    # creating connection without IPAddress does not make that much sense. So we are checking it here.
    if ($onlyAddVMWithIPAddress) {
        if (!$server.IPAddress) {
            Write-Output -Verbose "Ignoring $($server.Name) due to empty IP address..."
            continue
        }
    }

    # import...
    Write-Output -Verbose "Importing $($server.Name)..."
    # get folder, create it recursively if it does not exist, only when using vCenter
    if ($vi_type -eq "vcenter") {
        $lastFolder = CreateRoyalFolderHierarchy -FolderStructure ("Connections/Virtual Machines/" + $server.Folder) -Folder $doc -InheritFromParent $true
    }

    # create object
    $osType = $server.GuestId
    # description: either dnsName or vmName
    if ($server.DnsName) {
        $description = $server.DnsName
    } else {
        $description = $server.Name
    }

    # add guestOs if possible to description
    if ($server.GuestOS) {
        $description = $description + " (" + $server.GuestOS + ")"
    }

    # check if we want to use rDNS
    if ($useDNSReverseLookup) {
        # Try to use reverse dns to get hostname of IP address
        # Check for failure of rDNS
        try {
            $ipAddr = [System.Net.Dns]::GetHostEntry($server.IPAddress).HostName
        } catch {
            # Failure: Fallback to IP address
            $ipAddr = $server.IPAddress
        }

    } else {
        $ipAddr = $server.IPAddress
    }

    # create object depending on osType
    if ($osType -like "windows*") {
        $newConnection = New-RoyalObject -Folder $lastFolder -Type RoyalRDSConnection -Name $server.Name
        $newConnection.Description = $description
        $newConnection.URI = $ipAddr
        $newConnection.Notes = $server.Notes
    } else {
        $newConnection = New-RoyalObject -Folder $lastFolder -Type RoyalSSHConnection -Name $server.Name
        $newConnection.Description = $description
        $newConnection.URI = $ipAddr
        $newConnection.Notes = $server.Notes
    }
    Set-RoyalObjectValue -Object $newConnection -Property ManagementEndpointFromParent -Value $true | Out-Null
    Set-RoyalObjectValue -Object $newConnection -Property SecureGatewayFromParent -Value $true | Out-Null
}

# importing hosts into royal document
Write-Output -Verbose "+ Importing hosts..."
$lastFolder = CreateRoyalFolderHierarchy -FolderStructure "Connections/Hosts/" -Folder $doc -FolderIcon "/Flat/Hardware/CPU" -InheritFromParent $true
$hosts | ForEach-Object {
    $hostObj = $_

    Write-Output -Verbose "Importing $($hostObj.Name)..."

    # create folder recursively
    $lastFolder = CreateRoyalFolderHierarchy -FolderStructure ("Connections/Hosts/" + $hostObj.Name) -Folder $doc -FolderIcon "/Flat/Hardware/Server" -InheritFromParent $true

    # check if we want to use rDNS
    if ($useDNSReverseLookup) {
        # Try to use reverse dns to get hostname of IP address
        # Check for failure of rDNS
        try {
            $ipAddr = [System.Net.Dns]::GetHostEntry($hostObj.IPAddress).HostName
        } catch {
            # Failure: Fallback to IP address
            $ipAddr = $hostObj.IPAddress
        }

    } else {
        $ipAddr = $hostObj.IPAddress
    }

    # create SSH connection
    $newConnection = New-RoyalObject -Folder $lastFolder -Type RoyalSSHConnection -Name ($hostObj.Name + " SSH")
    $newConnection.Description = $hostObj.Type
    $newConnection.URI = $ipAddr
    Set-RoyalObjectValue -Object $newConnection -Property SecureGatewayFromParent -Value $true | Out-Null

    # create WEB connection
    $newConnection = New-RoyalObject -Folder $lastFolder -Type RoyalWebConnection -Name ($hostObj.Name + " Web")
    $newConnection.URI = "https://" + $ipAddr + "/"
    Set-RoyalObjectValue -Object $newConnection -Property SecureGatewayFromParent -Value $true | Out-Null

    # create VMware connection
    $newConnection = New-RoyalObject -Folder $lastFolder -Type RoyalVMwareConnection -Name $hostObj.Name
    $newConnection.Description = $hostObj.Type
    $newConnection.URI = $ipAddr
    Set-RoyalObjectValue -Object $newConnection -Property ManagementEndpointFromParent -Value $true | Out-Null
    Set-RoyalObjectValue -Object $newConnection -Property SecureGatewayFromParent -Value $true | Out-Null
}

# importing vCenter into document
if ($vi_type -eq "vcenter") {
    Write-Output -Verbose "+ Importing vCenter..."
    $lastFolder = CreateRoyalFolderHierarchy -FolderStructure "Connections/vCenter/" -Folder $doc -FolderIcon "/Flat/Hardware/Storage" -InheritFromParent $true

    Write-Output -Verbose "Importing vCenter $vi_ipaddr..."

    # create folder recursively
    $lastFolder = CreateRoyalFolderHierarchy -FolderStructure ("Connections/vCenter/" + $vi_ipaddr) -Folder $doc -FolderIcon "/Flat/Hardware/Screen Monitor" -InheritFromParent $true

    # check if we want to use rDNS
    if ($useDNSReverseLookup) {
        # Try to use reverse dns to get hostname of IP address
        # Check for failure of rDNS
        try {
            $ipAddr = [System.Net.Dns]::GetHostEntry($vi_ipaddr).HostName
        } catch {
            # Failure: Fallback to IP address
            $ipAddr = $vi_ipaddr
        }

    } else {
        $ipAddr = $vi_ipaddr
    }

    # create SSH connection
    $newConnection = New-RoyalObject -Folder $lastFolder -Type RoyalSSHConnection -Name "vCenter SSH"
    $newConnection.Description = "vCenter SSH"
    $newConnection.URI = $ipAddr
    Set-RoyalObjectValue -Object $newConnection -Property SecureGatewayFromParent -Value $true | Out-Null

    # create VMware connection
    $newConnection = New-RoyalObject -Folder $lastFolder -Type RoyalVMwareConnection -Name "vCenter"
    $newConnection.Description = "vCenter Object"
    $newConnection.URI = $ipAddr
    Set-RoyalObjectValue -Object $newConnection -Property ManagementEndpointFromParent -Value $true | Out-Null
    Set-RoyalObjectValue -Object $newConnection -Property SecureGatewayFromParent -Value $true | Out-Null

    # create WEB connection
    $newConnection = New-RoyalObject -Folder $lastFolder -Type RoyalWebConnection -Name "vCenter Web"
    $newConnection.Description = "vCenter Web"
    $newConnection.URI = "https://" + $ipAddr + "/"
    Set-RoyalObjectValue -Object $newConnection -Property SecureGatewayFromParent -Value $true | Out-Null

    # create VAMI WEB connection
    $newConnection = New-RoyalObject -Folder $lastFolder -Type RoyalWebConnection -Name "vCenter VAMI Web"
    $newConnection.Description = "vCenter VAMI Web"
    $newConnection.URI = "https://" + $ipAddr + ":5480/"
    Set-RoyalObjectValue -Object $newConnection -Property SecureGatewayFromParent -Value $true | Out-Null
}

# FINISHING
Write-Output -Verbose "+ Finishing..."

# ICON STUFF
# giving connections folder some love
$connectionsObject = Get-RoyalObject -Folder $doc -Name "Connections" -Type RoyalFolder
Set-RoyalObjectValue -Object $connectionsObject -Property CustomImageName -Value "/Flat/Software/Tree" | Out-Null

# setting connections>datacenter icon
# check if lastFolder is Datacenter folder-object (which means the lastFolder is directly below Connections folder)
$vmsFolderObject = Get-RoyalObject -Folder $connectionsObject -Type RoyalFolder -Name "Virtual Machines"
Get-RoyalObject -Folder $vmsFolderObject -Type RoyalFolder -Name "*" | ForEach-Object {
    if ($_.ParentID -eq $vmsFolderObject.ID) {
        Set-RoyalObjectValue -Object $_ -Property CustomImageName -Value "/Flat/Network/Cloud" | Out-Null
    }
}

# WRITE DOCUMENT
Write-Output -Verbose "Creating Royal Document $RoyalDocFileName..."
Out-RoyalDocument -Document $doc -FileName $RoyalDocFileName

# ...and we're done.
Write-Output -Verbose "+ Done."
