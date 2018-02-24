# importVIEnvironmentIntoRTS

This script is automatically creating a Royal TS document based on vSphere environment: it's importing virtual machines, hosts and the used vCenter, including IP address, the guests operating system, description and more.

Depending on the vSphere environment the script execution may take some time, also the reverse DNS lookup may slow down the process. If you would like to skip DNS Reverse Lookups you can specify parameter `-SkipDnsReverseLookup`. See more information below.

## REQUIREMENTS

* Operating Systems: any Windows OS with PowerShell installed
* PowerShell modules:
  * PowerCLI (for retrieving vSphere data, [Installation guide](https://blogs.vmware.com/PowerCLI/2017/04/powercli-install-process-powershell-gallery.html))
  * RoyalDocument (for interacting with Royal Documents, [Installation guide](https://content.royalapplications.com/Help/RoyalTS/V4/index.html?scripting_gettingstarted.htm))
* Access to VMware ESXi or VMware vCenter to retrieve the data using PowerCLI

## USAGE

* Download the script
* Execute the script with the corrected parameters.
  * **Example**: `C:\PS> .\importVIEnvironmentIntoRTS.ps1 -FileName "servers" -VITarget "vcenter.domain.local" -Credential (Get-Credential) -DoCsvExport`
* Wait until the document is created

### PARAMETERS

| Parameter                 | Type           | Description | Required | Default |
| ------------------------- | -------------- | ----------- | -------- | ------- |
| **-FileName**             | `String`       | The filename the document, and when enabled the CSV files, will be exported. Specify *without* file extension! | False | *vmw_servers* |
| **-VITarget**             | `String`       |The VITarget means the hostname/IP of either a standalone ESXi or vCenter to import the data from. | True | *None* |
| **-Credential**           | `PSCredential` | Specify a credential object for authentication. You can use (Get-Credential) cmdlet herefor. | True | *None* |
| **-DoCsvExport**          | `Switch`       | If parameter provided, the data will also be exported in the CSV format. Two seperated files: `<FileName>_vms.csv` and `<FielName>_hosts.csv` will be created. | False | *False* |
| **-SkipDnsReverseLookup** | `Switch`       | If parameter provided, the DNS Reverse Lookup will be skipped. Only use when it makes sense. | False | *False* |

## EXAMPLE OUTPUT

![RoyalTS Document Screenshot](https://raw.githubusercontent.com/patschi/royalts-scripts/master/screenshots/importVIEnvironmentIntoRTS-rtsdoc-1.png "Royal TS Document Screenshot")

## RECOMMENDATION

On new Royal TS installations by default the Internet Explorer engine will be used for newly created Web Page Connections. As the VMware vCenter Web Client nor the HTML5 Client are probably not working fine with Internet Explorer, I strongly recommend changing the default Web Page plugin to the embedded Chromium engine. Therefor please follow these steps:

1. Open the Royal TS application on your computer
2. Click on `"File"` in the top-left side, and then on `"Plugins"` in the left menu
3. Once opened, switch over to the connection type `"Web Page"` in the list.
4. Then you see the `Internet Explorer` and `Chromium-based` plugins there.
5. Select the Chromium-based one on the right side, and click `"Set as Default"` on the right-top.
6. Once done, you can click the `"OK"` button below to save the recent change.
7. Now on each `Web Page Connection` the Chromium plugin will be used, when not explicitly set otherwise.
