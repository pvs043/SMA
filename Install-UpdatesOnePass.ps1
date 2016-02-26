<#
    Workflow to Install Updates at One Server, One Pass

    Exit code:
          0 - Updates not requred
          1 - Error, server unreachable
         10 - Updates installed, reboot not needed
        100 - Updates installed, server rebooted
#>

Workflow Install-UpdatesOnePass
{
    [OutputType([string])]

    Param
    (
    [parameter(Mandatory=$true)]
        [string]$serverName

    )

    $VerbosePreference = "Continue"
    if (Test-Connection -ComputerName $serverName -Quiet) {
        Write-Verbose "Try update $serverName"
    }
    else {
        Write-Verbose "Server $serverName unreachable, exit."
        Return 1
    }

    $cred = Get-AutomationPSCredential -Name "UR\sco-svc"
    $retVal = InlineScript
    {
        $VerbosePreference = "Continue"
        Write-Verbose "Searching for applicable updates..."
 
        $UpdateSession = New-Object -Com Microsoft.Update.Session
        $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
 
        $SearchResult = $UpdateSearcher.Search("IsInstalled=0 and Type='Software'")
        If ($SearchResult.Updates.Count -eq 0) {
            Write-Verbose "There are no applicable updates."
            Return 0
        }

        Write-Verbose ""
        Write-Verbose "List of applicable items on the machine:"
        For ($X = 0; $X -lt $SearchResult.Updates.Count; $X++) {
            $Update = $SearchResult.Updates.Item($X)
            $print = ($X + 1).ToString() + "> " + $Update.Title
            Write-Verbose $print
        }

        #Register Scheduled Task
        $Null = Register-ScheduledJob -Name "Install Updates" -RunNow -ScriptBlock {
            #Define update criteria.
            $Criteria = "IsInstalled=0 and Type='Software'";`
            #Search for relevant updates.
            $Searcher = New-Object -ComObject Microsoft.Update.Searcher;`
            $SearchResult = $Searcher.Search($Criteria).Updates;`
            #Download updates.
            $Session = New-Object -ComObject Microsoft.Update.Session;`
            $Downloader = $Session.CreateUpdateDownloader();`
            $Downloader.Updates = $SearchResult;`
            $Null = $Downloader.Download();`
            #Install updates.
            $Installer = New-Object -ComObject Microsoft.Update.Installer;`
            $Installer.Updates = $SearchResult;`
            #Result -> 2 = Succeeded, 3 = Succeeded with Errors, 4 = Failed, 5 = Aborted
            $Result = $Installer.Install();`
            If ($Result.RebootRequired -eq $True) {Write-Output 100} else {Write-Output 10}
        } #End scheduledjob scriptblock
        
        Write-Verbose ""
        do {
            Start-Sleep 30
            $j = Get-Job -Name "Install Updates"
            $tm = Get-Date
            Write-Verbose "Waiting for install ($tm)..."
        } while ($j.State -eq 'Running')

        Write-Output $j.Output

        Unregister-ScheduledJob -Name "Install Updates"
    } -PSComputerName $serverName -PSCredential $cred #-PSAuthentication Credssp

    if ($retVal -eq 100) {
        $tm = Get-Date -Format "hh:mm:ss"
        Write-Verbose "[$tm] Restart $serverName..."
        Restart-Computer -PSComputerName $serverName -PSCredential $cred -Force -Wait -Timeout 600
        $tm = Get-Date -Format "hh:mm:ss"
        Write-Verbose "[$tm] Done."
    }
    Write-Output $retVal
}
