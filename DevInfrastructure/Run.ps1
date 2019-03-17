[CmdletBinding()]
Param(
	[Parameter(Mandatory=$false)]
    [string] $DeployAfterValidation = "no"
)

Set-StrictMode -Version 3

function Format-ValidationOutput {
    param ($ValidationOutput, [int] $Depth = 0)
    Set-StrictMode -Off
    return @($ValidationOutput | Where-Object { $_ -ne $null } | ForEach-Object { @('  ' * $Depth + ': ' + $_.Message) + @(Format-ValidationOutput @($_.Details) ($Depth + 1)) })
}

function Validate-Template($templateFile, $resourceGroup, $templateParametersFile, $AdditionalParameters) {
	
	$ErrorMessages = Format-ValidationOutput (Test-AzureRmResourceGroupDeployment -ResourceGroupName ($resourceGroup) `
                                                                                  -TemplateFile $templateFile `
                                                                                  -TemplateParameterFile $templateParametersFile)

	if ($ErrorMessages) {
		Write-Error ('Validation returned the following errors:' + @($ErrorMessages))
		return $false
	}
	else {
		Write-Host 'Template is valid.'
		return $true
	}
}

function Deploy-Template($templateFile, $resourceGroup, $templateParametersFile) {	

	New-AzureRmResourceGroupDeployment -Name ((Get-ChildItem $templateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
										-ResourceGroupName ($resourceGroup) `
										-TemplateFile $templateFile `
										-TemplateParameterFile $templateParametersFile `
										-Force -Verbose `
										-ErrorVariable ErrorMessages

	if ($ErrorMessages) {
		Write-Error ('Template deployment returned the following errors:' + (@(@($ErrorMessages) | ForEach-Object { $_.Exception.Message.TrimEnd("`r`n") })))
	}
}

function Ensure-ResourceGroup($resourceGroup, $location) {
	$existingResourceGroup = Get-AzureRmResourceGroup -ResourceGroupName ( $resourceGroup) -ErrorAction SilentlyContinue *>&1

	if (!($existingResourceGroup)) {  
		New-AzureRmResourceGroup -Name ($resourceGroup) -Location $location
	}
}

$azureProfile = Join-Path $env:USERPROFILE '.azure\azureProfile.json'
if (-not(Test-Path $azureProfile)) {
	Connect-AzureRmAccount
} else {
	Get-AzureRmContext
}

$templateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, 'azuredeploy.json'))
$templateParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, ('azuredeploy.parameters.json')))
$resourceGroup = 'Development'
$location = 'Australia East'
$subscriptionId = $env:AzureSubId

Get-AzureRmSubscription -SubscriptionId $subscriptionId
Ensure-ResourceGroup -resourceGroup $resourceGroup -location $location

$isValid = Validate-Template -templateFile $templateFile -resourceGroup $resourceGroup -templateParametersFile $templateParametersFile

if ($isValid -and $DeployAfterValidation -eq 'yes') {
	Deploy-Template -templateFile $templateFile -resourceGroup $resourceGroup -templateParametersFile $templateParametersFile
}
