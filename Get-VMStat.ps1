#requires -Version 3
<#
  .DESCRIPTION
    Gathers VMware vSphere 'Compute' performance stats and generates InfluxDB
    Line Protocol lines.

  .NOTES
    Filename:	      Get-VMStat.ps1
    Version:	      0.1
    Author:         Gavin Morris
    Requires:       PowerShell 3.0 or later (PowerShell 5.1 preferred)
    Requires:       VMware PowerCLI 5.0 or later (PowerCLI 6.5.4 or later preferred)
                    VMWare PowerCLI 10.x or above IS NOT SUPPORTED
    Prior Art:      Inspired by, and/or snippets borrowed from:
                    Mike Nisk       -  vFlux-Stats-Kit
    
  .PARAMETER vCenter
  String. The IP Address or DNS name of the vCenter Server machine.
  For IPv6, enclose address in square brackets, for example [fe80::250:56ff:feb0:74bd%4].
  You may connect to one vCenter.  Does not support array of strings intentionally.
  
  .PARAMETER VMs
  Get realtime stats for VMs and write them to InfluxDB
  
  .PARAMETER InfluxDB
  InfluxDB database name, default 'esx'

  .PARAMETER InfluxURL
  InfluxDB server URL, default http://localhost:8086

  .EXAMPLE
  Invoke-vFluxCompute.ps1 -vCenter <VC Name or IP> -ReportVMs "vm1","vm2"
#>

[cmdletbinding()]
param (
  [Parameter(Mandatory,HelpMessage='vCenter Name or IP Address')]
  [string]$vCenter,
  [array]$VMs,
  [string]$InfluxDB,
  [string]$InfluxURL = "http://localhost:8086"
  [string]$InfluxUser = ""
  [string]$InfluxPass = ""
)

Begin {
  ## stat preferences
  $stat_id = "cpu.costop.summation","cpu.ready.summation","cpu.run.summation","cpu.wait.summation"

  ## Create the variables that we consume with Invoke-RestMethod later.
  $authheader = 'Basic ' + ([Convert]::ToBase64String([Text.encoding]::ASCII.GetBytes(('{0}:{1}' -f $InfluxUser, $InfluxPass))))
  $uri = ('{0}/write?db={1}' -f $InfluxURL, $InfluxDB)

  Connect-VIServer -Server $Computer -WarningAction Continue -ErrorAction Stop
}

Process {
# $vms = get-vm -name "karisma-interop"
# $stat = get-stat -entity $vms -stat "cpu.ready.summation" -maxsamples 6 -realtime -instance "" | `
#   select entity, timestamp, value, instance

  $Entities = Get-VM -name $VMs| Where-Object {$_.PowerState -eq 'PoweredOn'} | Sort-Object -Property Name
  foreach ($vm in $Entities) {
    $stats = Get-Stat -Entity $vm -Stat $stat_id -RealTime -MaxSamples 1 -Instance ""
    foreach ($stat in $stats) {

    }
  }
}

End {
  Disconnect-VIServer -Server '*' -Confirm:$false -Force -ErrorAction SilentlyContinue
}