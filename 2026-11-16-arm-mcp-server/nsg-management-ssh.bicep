// Incremental change used in the lesson's what-if, deploy, and verify flow.
// This does not replace the baseline DenySshFromInternet rule created by Terraform.

@description('Name of the existing network security group.')
param nsgName string

@description('Source prefix allowed to reach TCP 22. Replace the documentation range with your real management prefix.')
param managementPrefix string = '192.0.2.0/24'

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' existing = {
  name: nsgName
}

resource allowSshFromManagement 'Microsoft.Network/networkSecurityGroups/securityRules@2024-05-01' = {
  parent: nsg
  name: 'AllowSshFromManagement'
  properties: {
    priority: 100
    direction: 'Inbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRange: '22'
    sourceAddressPrefix: managementPrefix
    destinationAddressPrefix: '*'
    description: 'Allow SSH only from the specified management prefix. Priority 100 is evaluated before the internet deny at 200.'
  }
}
