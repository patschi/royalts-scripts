# importVIEnvironmentIntoRTS

This script is automatically creating a [Royal TS](https://royalapplications.com/ts/win/features) document based on your VMware vSphere environment: It is importing virtual machines, hosts and the used vCenter, including the vCenter folder hierarchy, IP address, the guest operating system, annotations and more.

Depending on the VMware vSphere environment the script execution may take some time, also the reverse DNS lookup may slow down the process a bit. If you would like to skip DNS Reverse Lookups for some reasons you can specify the optional parameter `-SkipDnsReverseLookup`. [Here](#parameters) you have an overview of all available parameters.

## SUPPORT

Please [open an issue on GitHub](https://github.com/patschi/royalts-scripts/issues) to create feature requests, ask questions or report any bugs. Thanks!

This script is provided on a free-to-use basis, there is no official support from the Royal Applications team nor there will be any guarantee of regarding its functionality or so.

Feel free to adjust the scripts to your personal or corporates needs, however it would be really awesome if you could share any improvements back with the community - thanks for any contributions! Any feedback, ideas and - of course - pull requests are strongly welcome!

## TODO

**Current version**: 2.1.0

- [x] ~~Rewrite script to use parameters instead of hardcoded values within script file~~ **Done in v2.0.0**
- [ ] Being able to update existing documents instead of always creating new one
- [x] ~~Support for multiple VMware vCenter connections, using same credentials~~ **Available starting v2.1.0**
- [ ] Support for multiple VMware vCenter connections, using different credentials

## REQUIREMENTS

* Operating System: any Windows OS with PowerShell installed (PowerShell Core not supported)
* PowerShell modules:
  * PowerCLI (for retrieving vSphere data, [Installation guide](https://blogs.vmware.com/PowerCLI/2017/04/powercli-install-process-powershell-gallery.html))
  * RoyalDocument (for interacting with Royal Documents, [Installation guide](https://content.royalapplications.com/Help/RoyalTS/V4/index.html?scripting_gettingstarted.htm))
* Access to VMware ESXi or VMware vCenter to retrieve the data using PowerCLI

## USAGE

* Download the script. [See below.](#download)
* Execute the script with the corrected [parameters](#parameters). See [examples](#examples) below.
* Wait until the document is created, which will look like [this](#example-output).

### DOWNLOAD

Some recent PowerShell versions have a cool `wget` alias to the cmldlet `Invoke-WebRequest` allowing you to easily download files. This way you can use it to quickly download the script like here:

```powershell
C:\PS> wget -OutFile importVIEnvironmentIntoRTS.ps1 https://raw.githubusercontent.com/patschi/royalts-scripts/master/importVIEnvironmentIntoRTS/importVIEnvironmentIntoRTS.ps1
```

### PARAMETERS

| Parameter                 | Type          | Description | Required | Default |
| ------------------------- | ------------- | ----------- | -------- | ------- |
| **VITarget**             | `String/Array` | The VITarget is the hostname/IP of either a standalone ESXi or vCenter to import the data from.<br /><br />Starting with v2.1.0 you can also specify multiple hosts. Current limitation is that the _same credentials are going to be used for each VITarget_. | True | *None* |
| **FileName**             | `String`       | The filename of the document. This name is also used when CSV export is enabled. Specify it the *without* file extension! | False | *vmw_servers* |
| **Credential**           | `PSCredential` | Specify a credential object for authentication. You can use `Get-Credential` cmdlet herefor. If not provided, `Connect-VIServer` of PowerCLI will try using the current user session. | False | *None* |
| **DoCsvExport**          | `Switch`       | If parameter provided, the data will also be exported in the CSV format. This will create two seperated files: `<FileName>_vms.csv` and `<FileName>_hosts.csv`. | False | *False* |
| **SkipDnsReverseLookup** | `Switch`       | If parameter provided, the DNS Reverse Lookup will be skipped. Only use when it makes sense. | False | *False* |

### EXAMPLES

Here are some usage examples:

```powershell
C:\PS> .\importVIEnvironmentIntoRTS.ps1 -VITarget "vcenter.domain.local" -FileName "vi_servers"
[...processing...]

C:\PS> .\importVIEnvironmentIntoRTS.ps1 -VITarget "vcenter01.domain.local","vcenter02.domain.local" -FileName "vi_servers"
[...processing...]

C:\PS> .\importVIEnvironmentIntoRTS.ps1 -VITarget "vcenter.domain.local" -FileName "vi_servers" -DoCsvExport
[...processing...]

C:\PS> .\importVIEnvironmentIntoRTS.ps1 -VITarget "esxi01.domain.local","vcenter02.domain.local" -FileName "esxi_vms" -Credential (Get-Credential)
[...processing...]

C:\PS> .\importVIEnvironmentIntoRTS.ps1 -VITarget "192.168.2.1" -FileName "servers" -Credential (Get-Credential) -DoCsvExport -SkipDnsReverseLookup
[...processing...]

C:\PS> $cred = Get-Credential
C:\PS> .\importVIEnvironmentIntoRTS.ps1 -VITarget "192.168.1.1" -FileName "servers_IPonly" -Credential $cred -SkipDnsReverseLookup
[...processing...]
```

## EXAMPLE OUTPUT

![RoyalTS Document Screenshot](https://raw.githubusercontent.com/patschi/royalts-scripts/master/screenshots/importVIEnvironmentIntoRTS-rtsdoc-1.png "Royal TS Document Screenshot")

## RECOMMENDATION

On new Royal TS installations by default the *Internet Explorer engine* will be used for created Web Page connections. As the VMware vCenter Web Client nor the HTML5 Client are probably not working fine with Internet Explorer, I strongly recommend using *embedded Chromium engine* as the default Web Page plugin. Therefor please follow these steps:

1. Open the Royal TS application on your computer.
2. Click on `File` in the top-left side, and then on `Plugins` in the left menu. ([Official plugins docs.](https://content.royalapplications.com/Help/RoyalTS/V4/index.html?introduction_plugins.htm))
3. Once opened, switch over to the connection type `Web Page` in the list.
4. Then you see the `Internet Explorer` and `Chromium-based` plugins there.
5. Select the Chromium-based one on the right side, and click `Set as Default` on the right-top.
6. Once done, you can click the `OK` button below to save the recent change.
7. Now on each `Web Page Connection` the Chromium plugin will be used, when not explicitly set otherwise.
