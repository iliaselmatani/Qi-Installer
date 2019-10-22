$AuthServer = 'Automate.QualityIP.com'

#Set Default Path
if (!($PSScriptRoot -match $env:SystemDrive)) {
    $ScriptPath = $PSScriptRoot
}
else {
    $ScriptPath = "$env:systemDrive\QiInstaller"
}
if (!(Test-Path $ScriptPath\logs)) {
    New-Item -ItemType Directory -Path $ScriptPath\logs | Out-Null
}

try {
    Find-Package nuget -force -erroraction stop | out-null
    Find-Package AutomateAPI -force -ErrorAction stop | out-null
    Import-Module AutomateAPI -ErrorAction stop
}
catch {
    (New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/gavsto/AutomateAPI/master/Public/Connect-AutomateAPI.ps1') | Invoke-Expression;
    (New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/gavsto/AutomateAPI/master/Public/Get-AutomateClient.ps1') | Invoke-Expression;
    (New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/gavsto/AutomateAPI/master/Public/Get-AutomateAPIGeneric.ps1') | Invoke-Expression;
    function Get-ConditionsStacked {
        param (
            [Parameter()]
            [string[]]$ArrayOfConditions
        )
    
        $FinalString = ($ArrayOfConditions) -join " And "
        Return $FinalString
      
    }
}

(New-Object System.Net.WebClient).DownloadString('https://gitlab.com/api/v4/projects/14874591/repository/files/Qi_Installer%2Eps1/raw?ref=master') | Invoke-Expression;

<#
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
function fixuri($uri){
    $type = $uri.GetType();
    $fieldInfo = $type.GetField('m_Syntax', ([System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic));
    $uriParser = $fieldInfo.GetValue($uri);
    $typeUriParser = $uriParser.GetType().BaseType;$fieldInfo = $typeUriParser.GetField('m_Flags', ([System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::FlattenHierarchy));
    $uriSyntaxFlags = $fieldInfo.GetValue($uriParser);
    $uriSyntaxFlags = $uriSyntaxFlags -band (-bnot 0x2000000);
    $uriSyntaxFlags = $uriSyntaxFlags -band (-bnot 0x20000);
    $fieldInfo.SetValue($uriParser, $uriSyntaxFlags);
};
$uri = New-Object System.Uri -ArgumentList ('https://gitlab.com/api/v4/projects/14874591/repository/files/Qi_Installer%2Eps1/raw?ref=master');
fixuri $uri;
$PrivateToken = 'iZukjgy--jToWBo5Xe1t';
$Header = @{'PRIVATE-TOKEN' = $PrivateToken};
Invoke-restmethod -Headers $Header -Method Get -Uri $URI | Invoke-Expression;
#>