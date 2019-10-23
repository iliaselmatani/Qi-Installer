function Connect-AutomateAPI {
    <#
    .SYNOPSIS
    Connect to the Automate API.
    .DESCRIPTION
    Connects to the Automate API and returns a bearer token which when passed with each requests grants up to an hours worth of access.
    .PARAMETER Server
    The address to your Automate Server. Example 'rancor.hostedrmm.com'
    .PARAMETER Credentials
    Takes a standard powershell credential object, this can be built with $CredentialsToPass = Get-Credential, then pass $CredentialsToPass
    .PARAMETER TwoFactorToken
    Takes a string that represents the 2FA number
    .PARAMETER AuthorizationToken
    Used internally when quietly refreshing the Token
    .PARAMETER SkipCheck
    Used internally when quietly refreshing the Token
    .PARAMETER Verify
    Specifies to test the current token, and if it is not valid attempt to obtain a new one using the current credentials. Does not refresh (re-issue) the current token.
    .PARAMETER Force
    Will not attempt to refresh a current session
    .PARAMETER Quiet
    Will not output any standard messages. Returns $True if connection was successful.
    .OUTPUTS
    Three strings into Script variables, $CWAServer containing the server address, $CWACredentials containing the bearer token and $CWACredentialsExpirationDate containing the date the credentials expire
    .NOTES
    Version:        1.1
    Author:         Gavin Stone
    Creation Date:  2019-01-20
    Purpose/Change: Initial script development
    
    Update Date:    2019-02-12
    Author:         Darren White
    Purpose/Change: Credential and 2FA prompting is only if needed. Supports Token Refresh.
    
    .EXAMPLE
    Connect-AutomateAPI -Server "rancor.hostedrmm.com" -Credentials $CredentialObject -TwoFactorToken "999999"
    
    .EXAMPLE
    Connect-AutomateAPI -Quiet
    #>
    [CmdletBinding(DefaultParameterSetName = 'refresh')]
    param (
        [Parameter(ParameterSetName = 'credential', Mandatory = $False)]
        [System.Management.Automation.PSCredential]$Credential,
    
        [Parameter(ParameterSetName = 'credential', Mandatory = $False)]
        [Parameter(ParameterSetName = 'refresh', Mandatory = $False)]
        [Parameter(ParameterSetName = 'verify', Mandatory = $False)]
        [String]$Server = $Script:CWAServer,
    
        [Parameter(ParameterSetName = 'refresh', Mandatory = $False)]
        [Parameter(ParameterSetName = 'verify', Mandatory = $False)]
        [String]$AuthorizationToken = ($Script:CWAToken.Authorization -replace 'Bearer ', ''),
    
        [Parameter(ParameterSetName = 'refresh', Mandatory = $False)]
        [Parameter(ParameterSetName = 'credential', Mandatory = $False)]
        [Switch]$SkipCheck,
    
        [Parameter(ParameterSetName = 'verify', Mandatory = $False)]
        [Switch]$Verify,
    
        [Parameter(ParameterSetName = 'credential', Mandatory = $False)]
        [String]$TwoFactorToken,
    
        [Parameter(ParameterSetName = 'credential', Mandatory = $False)]
        [Switch]$Force,
    
        [Parameter(ParameterSetName = 'credential', Mandatory = $False)]
        [Parameter(ParameterSetName = 'refresh', Mandatory = $False)]
        [Parameter(ParameterSetName = 'verify', Mandatory = $False)]
        [Switch]$Quiet
    )
    
    Begin {
        # Check for locally stored credentials
        #        [string]$CredentialDirectory = "$($env:USERPROFILE)\AutomateAPI\"
        #        $LocalCredentialsExist = Test-Path "$($CredentialDirectory)Automate - Credentials.txt"
        If ($TwoFactorToken -match '.+') { $Force = $True }
        $TwoFactorNeeded = $False
    
        If (!$Quiet) {
            While (!($Server -match '.+')) {
                $Server = Read-Host -Prompt "Please enter your Automate Server address, IE: rancor.hostedrmm.com" 
            }
        }
        $Server = $Server -replace '^https?://', '' -replace '/[^\/]*$', ''
        $AuthorizationToken = $AuthorizationToken -replace 'Bearer ', ''
    } #End Begin
        
    Process {
        If (!($Server -match '^[a-z0-9][a-z0-9\.\-\/]*$')) { Throw "Server address ($Server) is missing or in invalid format."; Return }
        If ($SkipCheck) {
            $Script:CWAServer = ("https://" + $Server)
            If ($Credential) {
                Write-Debug "Setting Credentials to $($Credential.UserName)"
                $Script:CWAToken = $AutomateToken
            }
            If ($AuthorizationToken) {
                #Build the token
                $AutomateToken = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
                $Null = $AutomateToken.Add("Authorization", "Bearer $AuthorizationToken")
                Write-Debug "Setting Authorization Token to $($AutomateToken.Authorization)"
                $Script:CWAToken = $AutomateToken
            }
            Return
        }
        If (!$AuthorizationToken -and $PSCmdlet.ParameterSetName -eq 'verify') {
            Throw "Attempt to verify token failed. No token was provided or was cached."
            Return
        }
        Do {
            $AutomateAPIURI = ('https://' + $Server + '/cwa/api/v1')
            $testCredentials = $Credential
            If (!$Quiet) {
                If ($Credential) {
                    $testCredentials = $Credential
                }
                If (!$Credential -and ($Force -or !$AuthorizationToken)) {
                    If (!$Force -and $Script:CWACredentials) {
                        $testCredentials = $Script:CWACredentials
                    }
                    Else {
                        $Username = Read-Host -Prompt "Please enter your Automate Username"
                        $Password = Read-Host -Prompt "Please enter your Automate Password" -AsSecureString
                        $Credential = New-Object System.Management.Automation.PSCredential ($Username, $Password)
                        $testCredentials = $Credential
                    }
                }
                If ($TwoFactorNeeded -eq $True -and $TwoFactorToken -match '') {
                    $TwoFactorToken = Read-Host -Prompt "Please enter your 2FA Token"
                }
            }
    
            If ($testCredentials) {
                #Build the headers for the Authentication
                $PostBody = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
                $PostBody.Add("username", $testCredentials.UserName)
                $PostBody.Add("password", $testCredentials.GetNetworkCredential().Password)
                If (!([string]::IsNullOrEmpty($TwoFactorToken))) {
                    #Remove any spaces that were added
                    $TwoFactorToken = $TwoFactorToken -replace '\s', ''
                    $PostBody.Add("TwoFactorPasscode", $TwoFactorToken)
                }
                $RESTRequest = @{
                    'URI'         = ($AutomateAPIURI + '/apitoken')
                    'Method'      = 'POST'
                    'ContentType' = 'application/json'
                    'Body'        = $($PostBody | ConvertTo-Json -Compress)
                }
            }
            ElseIf ($PSCmdlet.ParameterSetName -eq 'refresh') {
                $PostBody = $AuthorizationToken -replace 'Bearer ', ''
                $RESTRequest = @{
                    'URI'         = ($AutomateAPIURI + '/apitoken/refresh')
                    'Method'      = 'POST'
                    'ContentType' = 'application/json'
                    'Body'        = $PostBody | ConvertTo-Json -Compress
                }
            }
            ElseIf ($PSCmdlet.ParameterSetName -eq 'verify') {
                $PostBody = $AuthorizationToken -replace 'Bearer ', ''
                $RESTRequest = @{
                    'URI'         = ($AutomateAPIURI + '/DatabaseServerTime')
                    'Method'      = 'GET'
                    'ContentType' = 'application/json'
                    'Headers'     = @{'Authorization' = "Bearer $PostBody" }
                }
            }
    
            #Invoke the REST Method
            Write-Debug "Submitting Request to $($RESTRequest.URI)`nHeaders:`n$($RESTRequest.Headers|ConvertTo-JSON -Depth 5)`nBody:`n$($RESTRequest.Body|ConvertTo-JSON -Depth 5)"
            Try {
                $AutomateAPITokenResult = Invoke-RestMethod @RESTRequest
            }
            Catch {
                Remove-Variable CWAToken, CWATokenKey -Scope Script -ErrorAction 0
                If ($testCredentials) {
                    Remove-Variable CWACredentials -Scope Script -ErrorAction 0
                }
                If ($Credential) {
                    Throw "Attempt to authenticate to the Automate API has failed with error $_.Exception.Message"
                    Return
                }
            }
                
            $AuthorizationToken = $AutomateAPITokenResult.Accesstoken
            If ($PSCmdlet.ParameterSetName -eq 'verify' -and !$AuthorizationToken -and $AutomateAPITokenResult) {
                $AuthorizationToken = $Script:CWAToken.Authorization -replace 'Bearer ', ''
            }
            $TwoFactorNeeded = $AutomateAPITokenResult.IsTwoFactorRequired
        } Until ($Quiet -or ![string]::IsNullOrEmpty($AuthorizationToken) -or 
            ($TwoFactorNeeded -ne $True -and $Credential) -or 
            ($TwoFactorNeeded -eq $True -and $TwoFactorToken -ne '')
        )
    } #End Process
    
    End {
        If ($SkipCheck) {
            If ($Quiet) {
                Return $False
            }
            Else {
                Return
            }
        }
        ElseIf ([string]::IsNullOrEmpty($AuthorizationToken)) {
            Remove-Variable CWAToken -Scope Script -ErrorAction 0
            Throw "Unable to get Access Token. Either the credentials you entered are incorrect or you did not pass a valid two factor token" 
            If ($Quiet) {
                Return $False
            }
            Else {
                Return
            }
        }
        Else {
            #Build the returned token
            $AutomateToken = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $AutomateToken.Add("Authorization", "Bearer $AuthorizationToken")
            #Create Script Variables for this session in order to use the token
            $Script:CWATokenKey = ConvertTo-SecureString $AuthorizationToken -AsPlainText -Force
            $Script:CWAServer = ("https://" + $Server)
            $Script:CWAToken = $AutomateToken
            If ($Credential) {
                $Script:CWACredentials = $Credential
            }
            If ($PSCmdlet.ParameterSetName -ne 'verify') {
                $AutomateAPITokenResult.PSObject.properties.remove('AccessToken')
                $Script:CWATokenInfo = $AutomateAPITokenResult
            }
            Write-Verbose "Token retrieved: $AuthorizationToken, expiration is $($Script:CWATokenInfo.ExpirationDate)"
    
            If (!$Quiet) {
                Write-Host -BackgroundColor Green -ForegroundColor Black "Successfully tested and connected to the Automate REST API. Token will expire at $($Script:CWATokenInfo.ExpirationDate)"
            }
            Else {
                Return $True
            }
        }
    }
}

function Get-AutomateClient {
    <#
        .SYNOPSIS
            Get Client information out of the Automate API
        .DESCRIPTION
            Connects to the Automate API and returns one or more full client objects
        .PARAMETER AllClients
            Returns all clients in Automate, regardless of amount
        .PARAMETER Condition
            A custom condition to build searches that can be used to search for specific things. Supported operators are '=', 'eq', '>', '>=', '<', '<=', 'and', 'or', '()', 'like', 'contains', 'in', 'not'.
            The 'not' operator is only used with 'in', 'like', or 'contains'. The '=' and 'eq' operator are the same. String values can be surrounded with either single or double quotes. IE (RemoteAgentLastContact <= 2019-12-18T00:50:19.575Z)
            Boolean values are specified as 'true' or 'false'. Parenthesis can be used to control the order of operations and group conditions.
        .PARAMETER OrderBy
            A comma separated list of fields that you want to order by finishing with either an asc or desc.
        .PARAMETER ClientName
            Client name to search for, uses wildcards so full client name is not needed
        .PARAMETER LocationName
            Location name to search for, uses wildcards so full location name is not needed
        .PARAMETER ClientID
            ClientID to search for, integer, -ClientID 1
        .PARAMETER LocationID
            LocationID to search for, integer, -LocationID 2
        .OUTPUTS
            Client objects
        .NOTES
            Version:        1.0
            Author:         Gavin Stone and Andrea Mastellone
            Creation Date:  2019-03-19
            Purpose/Change: Initial script development
        .EXAMPLE
            Get-AutomateClient -AllClients
        .EXAMPLE
            Get-AutomateClient -ClientId 4
        .EXAMPLE
            Get-AutomateClient -ClientName "Rancor"
        .EXAMPLE
            Get-AutomateClient -Condition "(City != 'Baltimore')"
        #>
    param (
        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = "IndividualClient")]
        [Alias('ID')]
        [int32[]]$ClientId,
    
        [Parameter(Mandatory = $false, ParameterSetName = "AllResults")]
        [switch]$AllClients,
    
        [Parameter(Mandatory = $false, ParameterSetName = "ByCondition")]
        [string]$Condition,
    
        [Parameter(Mandatory = $false, ParameterSetName = "CustomBuiltCondition")]
        [Parameter(Mandatory = $false, ParameterSetName = "AllResults")]
        [Parameter(Mandatory = $false, ParameterSetName = "ByCondition")]
        [string]$IncludeFields,
    
        [Parameter(Mandatory = $false, ParameterSetName = "CustomBuiltCondition")]
        [Parameter(Mandatory = $false, ParameterSetName = "AllResults")]
        [Parameter(Mandatory = $false, ParameterSetName = "ByCondition")]
        [string]$ExcludeFields,
    
        [Parameter(Mandatory = $false, ParameterSetName = "CustomBuiltCondition")]
        [Parameter(Mandatory = $false, ParameterSetName = "AllResults")]
        [Parameter(Mandatory = $false, ParameterSetName = "ByCondition")]
        [string]$OrderBy,
    
        [Alias("Client")]
        [Parameter(Mandatory = $false, ParameterSetName = "CustomBuiltCondition")]
        [string]$ClientName,
    
        [Parameter(Mandatory = $false, ParameterSetName = "CustomBuiltCondition")]
        [int]$LocationId,
    
        [Alias("Location")]
        [Parameter(Mandatory = $false, ParameterSetName = "CustomBuiltCondition")]
        [string]$LocationName
    )
    
    $ArrayOfConditions = @()
    
            
    if ($ClientID) {
        Return Get-AutomateAPIGeneric -AllResults -Endpoint "clients" -IDs $(($ClientID) -join ",")
    }
    
    if ($AllClients) {
        Return Get-AutomateAPIGeneric -AllResults -Endpoint "clients" -IncludeFields $IncludeFields -ExcludeFields $ExcludeFields -OrderBy $OrderBy
    }
    
    if ($Condition) {
        Return Get-AutomateAPIGeneric -AllResults -Endpoint "clients" -Condition $Condition -IncludeFields $IncludeFields -ExcludeFields $ExcludeFields -OrderBy $OrderBy
    }
    
    if ($ClientName) {
        $ArrayOfConditions += "(Name like '%$ClientName%')"
    }
    
    if ($LocationName) {
        $ArrayOfConditions += "(Location.Name like '%$LocationName%')"
    }
    
    if ($LocationID) {
        $ArrayOfConditions += "(Location.Id = $LocationId)"
    }
    
    $ClientFinalCondition = Get-ConditionsStacked -ArrayOfConditions $ArrayOfConditions
    
    $Clients = Get-AutomateAPIGeneric -AllResults -Endpoint "clients" -Condition $ClientFinalCondition -IncludeFields $IncludeFields -ExcludeFields $ExcludeFields -OrderBy $OrderBy
    
    $FinalResult = @()
    foreach ($Client in $Clients) {
        $ArrayOfConditions = @()
        $ArrayOfConditions += "(Client.Id = '$($Client.Id)')"
        $LocationFinalCondition = Get-ConditionsStacked -ArrayOfConditions $ArrayOfConditions
        $Locations = Get-AutomateAPIGeneric -AllResults -Endpoint "locations" -Condition $LocationFinalCondition -IncludeFields $IncludeFields -ExcludeFields $ExcludeFields -OrderBy $OrderBy
        $FinalClient = $Client
        Add-Member -inputobject $FinalClient -NotePropertyName 'Locations' -NotePropertyValue $locations
        $FinalResult += $FinalClient
    }
    
    return $FinalResult
}
function Get-AutomateAPIGeneric {
    <#
      .SYNOPSIS
        Internal function used to make generic API calls
      .DESCRIPTION
        Internal function used to make generic API calls
      .PARAMETER PageSize
        The page size of the results that come back from the API - limit this when needed
      .PARAMETER Page
        Brings back a particular page as defined
      .PARAMETER AllResults
        Will bring back all results for a particular query with no concern for result set size
      .PARAMETER Endpoint
        The individial URI to post to for results, IE computers?
      .PARAMETER OrderBy
        Order by - Used to sort the results by a field. Can be sorted in ascending or descending order.
        Example - fieldname asc
        Example - fieldname desc
      .PARAMETER Condition
        Condition - the searches that can be used to search for specific things. Supported operators are '=', 'eq', '>', '>=', '<', '<=', 'and', 'or', '()', 'like', 'contains', 'in', 'not'.
        The 'not' operator is only used with 'in', 'like', or 'contains'. The '=' and 'eq' operator are the same. String values can be surrounded with either single or double quotes.
        Boolean values are specified as 'true' or 'false'. Parenthesis can be used to control the order of operations and group conditions.
        The 'like' operator translates to the MySQL 'like' operator.
      .PARAMETER IncludeFields
        A comma delimited list of fields, when specified only these fields will be included in the result set
      .PARAMETER ExcludeFields
        A comma delimited list of fields, when specified these fields will be excluded from the final result set
      .PARAMETER IDs
        A comma delimited list of fields, when specified only these IDs will be returned
      .OUTPUTS
        The returned results from the API call
      .NOTES
        Version:        1.0
        Author:         Gavin Stone
        Creation Date:  20/01/2019
        Purpose/Change: Initial script development
      .EXAMPLE
        Get-AutomateAPIGeneric -Page 1 -Condition "RemoteAgentLastContact <= 2019-12-18T00:50:19.575Z" -Endpoint "computers?"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ParameterSetName = "Page")]
        [ValidateRange(1,1000)]
        [int]
        $PageSize = 1000,

        [Parameter(Mandatory = $true, ParameterSetName = "Page")]
        [ValidateRange(1,65535)]
        [int]
        $Page,

        [Parameter(Mandatory = $false, ParameterSetName = "AllResults")]
        [switch]
        $AllResults,

        [Parameter(Mandatory = $true)]
        [string]
        $Endpoint,

        [Parameter(Mandatory = $false)]
        [string]
        $OrderBy,

        [Parameter(Mandatory = $false)]
        [string]
        $Condition,

        [Parameter(Mandatory = $false)]
        [string]
        $IncludeFields,

        [Parameter(Mandatory = $false)]
        [string]
        $ExcludeFields,

        [Parameter(Mandatory = $false)]
        [string]
        $IDs,

        [Parameter(Mandatory = $false)]
        [string]
        $Expand
    )
    
    begin {
        #Build the URL to hit
        $url = ($Script:CWAServer + '/cwa/api/v1/' + $EndPoint)

        #Build the Body Up
        $Body = @{}

        #Put the page size in
        $Body.Add("pagesize", "$PageSize")

        if ($page) {
            
        }

        #Put the condition in
        if ($Condition) {
            $Body.Add("condition", "$condition")
        }

        #Put the orderby in
        if ($OrderBy) {
            $Body.Add("orderby", "$orderby")
        }

        #Include only these fields
        if ($IncludeFields) {
            $Body.Add("includefields", "$IncludeFields")
        }

        #Exclude only these fields
        if ($ExcludeFields) {
            $Body.Add("excludefields", "$ExcludeFields")
        }

        #Include only these IDs
        if ($IDs) {
            $Body.Add("ids", "$IDs")
        }

        #Expands in the returned object
        if ($Expand) {
          $Body.Add("expand", "$Expand")
        }
    }
    
    process {
        if ($AllResults) {
            $ReturnedResults = @()
            [System.Collections.ArrayList]$ReturnedResults
            $i = 0
            DO {
                [int]$i += 1
                $URLNew = "$($url)?page=$($i)"
                try {
                    $return = Invoke-RestMethod -Uri $URLNew -Headers $script:CWAToken -ContentType "application/json" -Body $Body
                }
                catch {
                    Write-Error "Failed to perform Invoke-RestMethod to Automate API with error $_.Exception.Message"
                }

                $ReturnedResults += ($return)
            }
            WHILE ($return.count -gt 0)
        }

        if ($Page) {
            $ReturnedResults = @()
            [System.Collections.ArrayList]$ReturnedResults
            $URLNew = "$($url)?page=$($Page)"
            try {
                $return = Invoke-RestMethod -Uri $URLNew -Headers $script:CWAToken -ContentType "application/json" -Body $Body
            }
            catch {
                Write-Error "Failed to perform Invoke-RestMethod to Automate API with error $_.Exception.Message"
            }

            $ReturnedResults += ($return)
        }

    }
    
    end {
        return $ReturnedResults
    }
}
function Get-ConditionsStacked {
    param (
        [Parameter()]
        [string[]]$ArrayOfConditions
    )

    $FinalString = ($ArrayOfConditions) -join " And "
    Return $FinalString
  
}