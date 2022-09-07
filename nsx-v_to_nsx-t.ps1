#Requires -Modules VMware.VimAutomation.Core
#Requires -Version 5.1
#Install Module VMware 
#Install-Module -Name VMware.PowerCLI
##### https://vdc-download.vmware.com/vmwb-repository/dcr-public/06a3b3da-4c6d-4984-b795-5d64081a4b10/8e47d46b-cfa7-4c06-8b81-4f5548da3102/doc/doc/operations/POST-MoveVApp.html
##### https://vdc-download.vmware.com/vmwb-repository/dcr-public/06a3b3da-4c6d-4984-b795-5d64081a4b10/8e47d46b-cfa7-4c06-8b81-4f5548da3102/doc/doc//types/MoveVAppParamsType.html
##### https://www.vlabware.page/2021/08/moving-vapp-to-another-vcd-one-vcenter.html
##### https://kiwicloud.ninja/?p=68945
##### Print Org List with module https://github.com/jondwaite/Invoke-vCloud
##### http://jon.netdork.net/2011/03/23/powershell-xml-and-nested-elements/

#Login with Connect-CIServer

$userName = "my_login_VCD"
$securedValue = 'MyPassword'
$cloudDirector = "my_URL_VCD"

#Section Migration 
$orgname = "Client-MIGRATION"
$Source_vDCName = "vDCName_NSX-V"
$Target_VDCName = "vDCName_NSX-T"
$base_uri = "https://" + $cloudDirector + "/"

connect-ciserver $cloudDirector  -User $userName -Password $securedValue

$mySessionId = ($Global:DefaultCIServers | Where-Object { $_.Name -eq $cloudDirector }).SessionId

if ($mySessionId) {                     # Found a matching session - Connect-CIServer has been used:
    $ApiVersion = '36.2'
    $Method = 'GET'
    $APITimeout = "30"
    $Accept= 'application/*+xml'
    $Headers = @{'x-vcloud-authorization'=$mySessionId}
    $Headers.Add("Accept","$($Accept);version=$($ApiVersion)")

} else {                                # No connected session found, see if we have a token:
    
        Write-Error ("No existing Connect-CIServer session found and no vCloudToken or vCloudJWT token specified.")
        Write-Error ("Cannot authenticate to the vCloud API, exiting.")
        Return
 }


 #Retrieve href vapp source and target
 $counter = 0
 $org = get-org -name $orgname
 $Target_VDC = Get-OrgVdc -name $Target_VDCName
 $Target_VDC_id = ($Target_VDC.id -split ":")[3]
 $Source_VDC = Get-OrgVdc -name $Source_vDCName
 $Source_vApps = $Source_VDC | Get-CIVApp
 $Target_uri = "$($base_uri)api/vdc/$Target_VDC_id/action/moveVApp"
 Write-Host -NoNewline "URI : "-ForegroundColor Green


 $Move_headers = @{}
 $Move_headers = $headers.clone()
 $Move_headers.Add("Content-Type","application/vnd.vmware.vcloud.MoveVAppParams+xml")
 $Request_headers = @{}
 $Request_headers = $headers.clone()
 $Request_headers.Add("Content-Type","application/vnd.vmware.vcloud.session+xml;version=36.2") 

 
 #Request each item
 Foreach ($Source_vApp in $Source_vApps){
    $vAppCount = $Source_vApps.count
    $counter += 1
    $Source_vAppName = $Source_vApp.name
    $vapp_href = $Source_vApp.ExtensionData.href
    Write-Output $vapp_href
    $vms = $Source_vApp | Get-CIVM
    Write-Output $vms
    pause “Press any key to continue”
    #Create XML Body
# Remove-Variable XML_body 
[System.Xml.XmlDocument]$XML_body = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>

<MoveVAppParams xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:ns7="http://schemas.dmtf.org/ovf/envelope/1" xmlns:ns8="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns:ns9="http://www.vmware.com/schema/ovf">
</MoveVAppParams>
'@
  
#Create element vApp “Source”
    $SourcevApp = $XML_body.CreateElement("Source",$XML_body.MoveVAppParams.NamespaceURI)
    $SourcevApp.SetAttribute("href",$vapp_href)
    $XML_body.MoveVAppParams.AppendChild($SourcevApp)

    Write-Output [System.Xml.Linq.XDocument]::Parse($XML_body.OuterXml).ToString()
    
#API Request vApp
    $uri = "$vapp_href/networkConfigSection"
    Write-Host -NoNewline “Invoke vApp Request API: " -ForegroundColor Green

    try{$vApp_request = Invoke-RestMethod -uri $uri -Headers $Request_headers -Method Get }
    catch{$err_mes = $_}
    
#Create node "NetworkConfigSection"
    $NetworkConfigSection=$XML_body.CreateNode("element","NetworkConfigSection",$XML_body.MoveVAppParams.NamespaceURI)
    $NetworkConfigSection =$XML_body.importnode($vApp_request.NetworkConfigSection, $true)
    $XML_body.MoveVAppParams.appendChild($NetworkConfigSection)
   
    
foreach ($vm in $vms){
    $vm_href = $vm.ExtensionData.Href
    $vm_sp_name = $vm.extensiondata.storageprofile.name
    $Target_vdc_sp_id = (($Target_VDC.ExtensionData.VdcStorageProfiles.VdcStorageProfile | where-object {$_.name -eq $vm_sp_name}).id -split “:”)[3]
    $Target_vdc_sp_href = "$($base_uri)api/vdcStorageProfile/$Target_vdc_sp_id"
    
#API Request VM
    $uri = "$vm_href/networkConnectionSection"
    Write-Output -NoNewline “Invoke Request API: " -ForegroundColor Green

    try{$VM_request = Invoke-RestMethod -uri $uri -Headers $headers -Method Get }
    catch{$err_mes = $_}
    
#Create node “SourcedItem”
    $SourceItem=$XML_body.CreateNode("element","SourcedItem",$XML_body.MoveVAppParams.NamespaceURI)
    $XML_body.MoveVAppParams.appendChild($SourceItem)
    
#Create element VM "Source"
    $SourceVM = $XML_body.CreateElement("Source",$XML_body.MoveVAppParams.NamespaceURI)
    $SourceVM.SetAttribute(“href”,$vm_href)
    $SourceItem.AppendChild($SourceVM)
    
#Create node "InstantiationParams"
    $InstantiationParams=$XML_body.CreateNode("element","InstantiationParams",$XML_body.MoveVAppParams.NamespaceURI)
    $SourceItem.appendChild($InstantiationParams)
    
#Create node "NetworkConnectionSection"
    $NetworkConnectionSection=$XML_body.CreateNode("element","NetworkConnectionSection",$XML_body.MoveVAppParams.NamespaceURI)
    $NetworkConnectionSection = $XML_body.importnode($VM_request.NetworkConnectionSection, $true)
    $InstantiationParams.appendChild($NetworkConnectionSection)
    
#Create element "StorageProfile"
    $StorageProfile = $XML_body.CreateElement("StorageProfile",$XML_body.MoveVAppParams.NamespaceURI)
    $StorageProfile.SetAttribute("href",$Target_vdc_sp_href)
    $SourceItem.AppendChild($StorageProfile)
    
    }
    
    Write-Host -NoNewline "Move vApp: " -ForegroundColor Green
    Write-Output $Source_vAppName
    Write-Host -NoNewline "Invoke Request API: " -ForegroundColor Green
    Write-Output [System.Xml.Linq.XDocument]::Parse($XML_body.OuterXml).ToString()

    $fileName = "XMLExported_$Source_vAppName.xml"
    $XML_body.save($fileName)

    pause “Press any key to continue”
   # [XML]$XML_body = Get-Content $fileName

    try{$request = Invoke-WebRequest -uri $Target_uri -Headers $Move_headers -Method Post -Body $XML_body}
    catch{$err_mes = $_}
    
    if($request.StatusCode -eq ‘202’){Write-Host "Success" -ForegroundColor White}
    else{Write-Host “Failed” -ForegroundColor Red;Write-Host $err_mes.Exception -ForegroundColor Red}
    
    if ($counter -ne $vAppCount){Write-Host -NoNewline "Migrating vApp : " -ForegroundColor Green
    Write-Output “$counter on $vAppCount”
    Write-Host “Waiting for next vApp” -ForegroundColor Yellow
    Write-Host -NoNewline “Target URI : ” -ForegroundColor Green
    Write-Output $Target_uri
    pause “Press any key to continue”
    
    } else {
    Write-Host -NoNewline "Migrating vApp : " -ForegroundColor Green
    Write-Output "$counter on $vAppCount"
    Write-Host -NoNewline “Target URI : " -ForegroundColor Green
    Write-Output $Target_uri
    }
    }
    
    Disconnect-CIserver * -Confirm:$False  
   
