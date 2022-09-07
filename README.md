How to Move (Live) vApps Across Org VDCs

The moveVApp API is fairly new and still evolving. For example VMware Cloud Director 10.3.2 added support for move router vApps. 
Movement of running encrypted vApps will be supported in the future. So be aware there might be limitations based on your VCD version.

The vApp can be moved across Org VDCs/Provider VDCs/clusters, vCenters of the same tenant but it will not work across associated Orgs for example. 
It also cannot be used for moving vApps across clusters/resource pools in the same Org VDC (for that use Migrate VM UI/API). 
Obviously the underlying vSphere platform must support vMotions across the involved clusters or vCenters. 
NSX backing (V to T) change is also supported.

How to use this script

You need to edit 
$userName = "User"
$securedValue = 'Password'
$cloudDirector = "URI"
$orgname = "OrgNameMigration
$Source_vDCName = "vDC_NSX_V"
$Target_VDCName = "vDC_NSX-T"
