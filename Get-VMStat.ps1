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
  [string]$Computer,
  [array]$VMs,
  [string]$InfluxDB = "perf_mdhbs_esx",
  [string]$InfluxURL = "http://localhost:8086",
  [string]$InfluxUser = "",
  [string]$InfluxPass = ""
)

Begin {
  ## stat preferences
  $stat_id = 
    "cpu.costop.summation",
    "cpu.ready.summation", 
    "cpu.run.summation",
    "cpu.wait.summation"

  ## Create the variables that we consume with Invoke-RestMethod later.
  #$authheader = 'Basic ' + ([Convert]::ToBase64String([Text.encoding]::ASCII.GetBytes(('{0}:{1}' -f $InfluxUser, $InfluxPass))))
  $uri = ('{0}/write?db={1}' -f $InfluxURL, $InfluxDB)

  Connect-VIServer -Server $Computer -WarningAction Continue -ErrorAction Stop
}

Process {
  #Import PowerCLI module/snapin if needed
  If(-Not(Get-Module -Name VMware.PowerCLI -ListAvailable -ErrorAction SilentlyContinue)){
    $vMods = Get-Module -Name VMware.* -ListAvailable -Verbose:$false
    If($vMods) {
      foreach ($mod in $vMods) {
        Import-Module -Name $mod -ErrorAction Stop -Verbose:$false
      }
      Write-Verbose -Message 'PowerCLI 6.x Module(s) imported.'
    }
    Else {
      If(!(Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue)) {
        Try {
          Add-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction Stop
          Write-Verbose -Message 'PowerCLI 5.x Snapin added; recommend upgrading to PowerCLI 6.x'
        }
        Catch {
          Write-Warning -Message 'Could not load PowerCLI'
          Throw 'PowerCLI 5 or later required'
        }
      }
    }
  }

  $run_freq_min = 1
  $sample_count = ($run_freq_min * 60) / 20;

  $Entities = Get-VM -Name $VMs | Where-Object PowerState -eq 'PoweredOn' | Sort-Object -Property Name
  $stat = Get-Stat -Entity $Entities -Stat $stat_id -RealTime -MaxSamples $sample_count -Instance ""

  $groups = $stat | Group-Object -Property Entity, Timestamp, IntervalSecs

  foreach ($group in $groups) {
    $vm = $group.Values[0]
    $ts = $group.Values[1]
    $int_s = $group.Values[2]

    $line = "cpu,vm={0},int={1},cpu={2},ram={3} " -f $vm.Name, $int_s, $vm.NumCPU, $vm.MemoryGB

    $metrics = $group.Group | Sort-Object -Property MetricId

    foreach ($metric in $group.Group) {
      $n = $metric.MetricId.Substring(4, $metric.MetricId.Length - ".summation".Length - 4)
      $line += "{0}={1}i," -f $n, $metric.Value
    }

    if ($line.Length -gt 0) {
      $line = $line.Substring(0, $line.Length - 1)
    }

    [long]$epoch_sec = ($ts-(Get-Date -Date '1/1/1970')).TotalSeconds #seconds since Unix epoch
    $line += " " + $epoch_sec

    Write-Host $line
  }
}

End {
  Disconnect-VIServer -Server '*' -Confirm:$false -Force -ErrorAction SilentlyContinue
}