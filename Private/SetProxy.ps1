Function SetProxy {
    $Proxy = [System.Net.WebRequest]::GetSystemWebProxy().GetProxy("https://www.google.com").AbsoluteURI
    Write-Output $Proxy
}