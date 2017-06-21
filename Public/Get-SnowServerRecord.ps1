Function Get-SnowServerRecord {
<#
.SYNOPSIS
    Return server details from the ServiceNow CMDB

.DESCRIPTION
    Return server details from the ServiceNow CMDB

    Targets the default cmdb_ci_server ServiceNow table and returns a relevant subset of the server record(s)
    Any ServiceNow instance can be targeted using the mandatory 'SnowInstance' parameter

.EXAMPLE
    Returns the details for a server named Server01 from https://companyname.service-now.com

    Get-SnowServerRecord -Servername Server01 -Credential $Credential -SnowInstance companyname

.NOTES
    Transfer Encoding compression, again for speed of the Invoke-RestMethod?

.PARAMETER Servername
    The server or servers to query

.PARAMETER Credential

.PARAMETER SnowInstance
    The name of the ServiceNow instance. For example if your access URL is https://companyname.service-now.com,
    you would specify 'companyname' as this parameter's value

#>
    [CmdletBinding()]
    Param
    (
        [parameter(ValueFromPipelineByPropertyName,ValueFromPipeline,Mandatory=$True)]
        [alias('Name')]
        $Servername,
        
        [Parameter(Mandatory=$True)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,
        
        [Parameter(Mandatory=$True)]
        $SnowInstance
    )
    
    Begin 
    {

        Write-Verbose "Begin block - Setting proxy variable and ServiceNow server table URI "
        $Proxy = SetProxy
        $Headers = BuildSnowHeaders
        $BaseUri = "https://$SnowInstance.service-now.com/api/now/table/cmdb_ci_server?name="

        #Could have a function here to build RestQueryParams? Have to output a hashtable object
        $RestQueryParams = @{Proxy = $Proxy
                             ProxyUseDefaultCredentials = $True
                             Credential = $Credential
                             Headers = $Headers
                             Method = 'Get'
                             ErrorAction = 'Stop'
                             Uri = $BaseUri
                             UseBasicParsing = $True
                             SessionVariable = 'Session'}

        if ($PSVersionTable.PSVersion.Major -ne '5') {
            $RestQueryParams.Remove('UseBasicParsing')
        }

        #Should this be wrapped in a try/catch block?
        Invoke-RestMethod @RestQueryParams -Verbose:$false | Out-Null
        

        $RestQueryParams.Remove('SessionVariable')
        $RestQueryParams.Remove('Credential')
        $RestQueryParams.Add('WebSession', $Session)

        $StatusLookup = @{'103' = 'Live'
                          '105' = 'Decommissioned'
                          '107' = 'Powered Down'
                          '109' = 'Decommissioned - Reusable'}
    }

    Process
    {
        Write-Verbose "Process block - Returning ServiceNow details for all servers passed to the cmdlet"

        $Servername | ForEach-Object {          
            $Server = $_

            try 
            {
                $ServerUri = "$BaseUri" + "$Server"
                Write-Verbose "Server query URI is $ServerUri"

                $RestQueryParams["Uri"] = $ServerUri
                $ServerRecord = (Invoke-RestMethod @RestQueryParams).result
                $ServerStatus = $ServerRecord.Install_Status

                $ModelUri = $ServerRecord.model_id.link  
                $RestQueryParams["Uri"] = $ModelUri
                $Model = (Invoke-RestMethod @RestQueryParams).result

                $DepartmentUri = $ServerRecord.department.link
                $RestQueryParams["Uri"] = $DepartmentUri
                $Department = (Invoke-RestMethod @RestQueryParams).result

                $Properties = [ordered]@{Name = $ServerRecord.Name
                                         Model = $Model.Display_Name
                                         UpdatedBy = $ServerRecord.Sys_Updated_By
                                         Classification = $ServerRecord.Classification
                                         Description = $ServerRecord.Short_Description
                                         Department = $Department.Name
                                         Status = $StatusLookup[$ServerStatus]
                                         CpuType = $ServerRecord.Cpu_Type
                                         CpuSpeed = $ServerRecord.Cpu_Speed
                                         Ram = $ServerRecord.Ram}
            }
            catch 
            {
                Write-Verbose "Server named $Server not found in ServiceNow"
                $Properties = [ordered]@{Name = $Server
                                         Model = $null
                                         UpdatedBy = $null
                                         Classification = $null
                                         Description = $null
                                         Department = $null
                                         Status = $null
                                         CpuType = $null
                                         CpuSpeed = $null
                                         Ram = $null}
            }
            finally
            {
                $Result = New-Object -TypeName PSObject -Property $Properties
                $Result.PSObject.Typenames.Insert(0,'Snow.Record.Server')

                Write-Output $Result
            }
        }
    }
}