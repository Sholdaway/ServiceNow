Function BuildSnowHeaders {
<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.EXAMPLE
An example

.NOTES
General notes
#>

    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Accept", 'application/json')
    $Headers.Add("Content-Type", 'application/json')

    Write-Output $Headers
}
