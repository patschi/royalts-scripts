# royalts-scripts

This repository provides several (*currently only one*) scripts for the application Royal TS, more information here: [royalapplications.com/ts/win/features](https://royalapplications.com/ts/win/features)

Any feedback, suggestions, ideas and - ofcourse - pull requests are welcome.

## Scripts

### importVIEnvironmentIntoRTS
[importVIEnvironmentIntoRTS](/royalts-scripts/blob/master/screenshots/importVIEnvironmentIntoRTS-rtsdoc-1.png) is automatically creating a Royal TS document based on vSphere environment: it's importing virtual machines, hosts and the used vCenter, including IP address, the guests operating system, description and more.

Execution may take some time, mainly because the reverse DNS lookup slows down the process noticeably. Optionally you may set `$useDNSReverseLookup` to `$false` to disable the lookup.

**Requirements**
 * Operating Systems: Windows with PowerShell installed
 * PowerShell modules:
   * PowerCLI (for retrieving vSphere data, [Installation guide](https://blogs.vmware.com/PowerCLI/2017/04/powercli-install-process-powershell-gallery.html))
   * RoyalDocument (for interacting with Royal Documents, [Installation guide](https://content.royalapplications.com/Help/RoyalTS/V4/index.html?scripting_gettingstarted.htm))
 * Access to VMware ESXi or VMware vCenter to retrieve the data using PowerCLI

**Usage**
 * Download script
 * Modify variables within the script file (see "*CONFIGURATION*" area)
 * Run it and wait until document is being created

**Example output**
![importVIEnvironmentIntoRTS RoyalTS Document Screenshot](/royalts-scripts/blob/master/screenshots/importVIEnvironmentIntoRTS-rtsdoc-1.png "Royal TS Document Screenshot")
