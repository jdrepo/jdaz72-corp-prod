function Get-RandomCharacters($length, $characters) {
    $random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.length }
    $private:ofs=""
    return [String]$characters[$random]
}
function Scramble-String([string]$inputString){     
$characterArray = $inputString.ToCharArray()   
$scrambledStringArray = $characterArray | Get-Random -Count $characterArray.Length     
$outputString = -join $scrambledStringArray
return $outputString 
}

$password = Get-RandomCharacters -length 5 -characters 'abcdefghiklmnoprstuvwxyz'
$password += Get-RandomCharacters -length 2 -characters 'ABCDEFGHKLMNOPRSTUVWXYZ'
$password += Get-RandomCharacters -length 3 -characters '1234567890'
$password += Get-RandomCharacters -length 2 -characters '@#*+'

#not allowed character " ' ` / \ < % ~ | $ & !

$password = Scramble-String $password

#$KV_NAME = "kv-weu-001-prod-rp3i5x"
#SECRET_NAME = ""
Write-Host "Adding the current public ip to the key vault allow list"
Write-Host "KeyVault Name: "$env:KV_NAME
Write-Host "Resource Group: "$env:RG_NAME 
Write-Host "Secret Name: "$env:SECRET_NAME

$publicIp = "$((Invoke-WebRequest -Uri https://ifconfig.me/ip).content)/32"
Write-Host 'My public ip: '$publicIp
Add-AzKeyVaultNetworkRule -VaultName $env:KV_NAME -IpAddressRange $publicIp -ResourceGroupName $env:RG_NAME

# Do what you want with secrets, certs

$secret = Get-AzKeyVaultSecret -VaultName $env:KV_NAME -Name $env:SECRET_NAME
if (!$secret)
{
    $secretvalue = ConvertTo-SecureString $password -AsPlainText -Force
    $secret = Set-AzKeyVaultSecret -VaultName $env:KV_NAME -Name $env:SECRET_NAME -SecretValue $secretvalue
}

Write-Host "Removing current public ip address from allow list"
Remove-AzKeyVaultNetworkRule -VaultName $env:KV_NAME -IpAddressRange $publicIp 