function InvokeStep {
    process {
        $date = Get-Date
        $title = '{0} {1}: {2}' -f $date.ToShortDateString(), $date.ToShortTimeString(), $_
        Write-Host ("`n{0}`n{1}`n" -f $title, ('=' * $title.Length))
        & $_
    }
}

function ConfigureNetwork {
    <#
    .SYNOPSIS
        Set the network connection profile to Private. Default is Public.
    #>

    Set-NetConnectionProfile -NetworkCategory Private -PassThru
    Set-NetFirewallProfile -Name Public, Private, Domain -Enabled False
    Get-NetAdapterBinding -ComponentID 'ms_tcpip6' | Disable-NetAdapterBinding -ComponentID ms_tcpip6 -PassThru
}

function EnableRDP {
    <#
    .SYNOPSIS
        Enable RDP.
    #>

    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -Value 0
    Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'
}

function InstallChocolatey {
    <#
    .SYNOPSIS
        Install chocolatey.
    #>

    $erroractionpreference = 'Stop'
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = 'Tls, Tls11, Tls12'
        Invoke-WebRequest https://chocolatey.org/install.ps1 -UseBasicParsing | Invoke-Expression
    } catch {
        throw
    }
}

function InstallPackages {
    <#
    .SYNOPSIS
        Install VMware tools.
    .DESCRIPTION
        Installs VMware tools before handing over to provisioning. Avoids a disconnect caused by reinstallation of the vmxnet3 drivers.
    #>

    choco install vmware-tools -y --no-progress
}

function AddStartupTask {
    <#
    .SYNOPSIS
        Add the server configuration script.
    #>

    New-Item C:\script -ItemType Directory
    Copy-Item a:\provisionServer.ps1 C:\script

    $params = @{
        Execute  = 'powershell.exe'
        Argument = '-ExecutionPolicy Bypass -NoProfile -File c:\script\provisionServer.ps1'
    }
    $action = New-ScheduledTaskAction @params

    $params = @{
        TaskName = 'provisionServer'
        Trigger  = New-ScheduledTaskTrigger -AtStartup
        Action   = $action
        User     = 'NT AUTHORITY\SYSTEM'
        RunLevel = 'Highest'
        Force    = $true
    }
    Register-ScheduledTask @params
}

function Reboot {
    Restart-Computer -Force
}

try {
    New-Item 'c:\log' -ItemType Directory -Force

    $timeStamp = [DateTime]::Now.ToString('yyyyMMdd-HHmmss')
    Start-Transcript -Path ('c:\log\buildServer.{0}.log' -f $timeStamp)

    'ConfigureNetwork',
    'EnableRDP',
    'InstallChocolatey',
    'InstallPackages',
    'AddStartupTask',
    'Reboot' | InvokeStep
} catch {
    throw
} finally {
    Stop-Transcript
}