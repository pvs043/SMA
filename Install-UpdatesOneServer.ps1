<#
    Workflow to Install Updates at One Server
    Reboot Server, if needed

    Exit code:
          0 - Updates installed
          1 - Error, server unreachable
#>

Workflow Install-UpdatesOneServer
{
    [OutputType([int])]

    Param
    (
    [parameter(Mandatory=$true)]
        [string]$serverName

    )
    $VerbosePreference = "Continue"
    do {
        $res = Install-UpdatesOnePass -serverName $serverName
        if ($res -eq 10) {
            Write-Verbose "Updates installed, reboot not needed"
        }
        elseif ($res -eq 100) {
            Write-Verbose "Updates installed, server rebooted"
        }
    } while ( ($res -ne 0) -and ($res -ne 1) )
    Write-Output $res
}