locals {
  # Subnet plan (derived from the VNET CIDRs)
  bastion_cidr     = cidrsubnet(var.hub_address_space, 10, 4)       # 10.0.1.0/26
  privatelink_cidr = cidrsubnet(var.hub_address_space, 8, 2)        # 10.0.2.0/24
  web_cidr         = cidrsubnet(var.spoke_app_address_space, 8, 1)  # 10.1.1.0/24
  db_cidr          = cidrsubnet(var.spoke_app_address_space, 8, 2)  # 10.1.2.0/24
  mgmt_cidr        = cidrsubnet(var.spoke_mgmt_address_space, 8, 1) # 10.2.1.0/24
}

# ---------------------------------------------------------------------------
# VNETs
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${var.name_base}-hub"
  location            = var.location
  resource_group_name = var.hub_resource_group_name
  address_space       = [var.hub_address_space]
  tags                = var.tags
}

resource "azurerm_virtual_network" "spoke_app" {
  name                = "vnet-${var.name_base}-spoke-app"
  location            = var.location
  resource_group_name = var.workload_resource_group
  address_space       = [var.spoke_app_address_space]
  tags                = var.tags
}

resource "azurerm_virtual_network" "spoke_mgmt" {
  name                = "vnet-${var.name_base}-spoke-mgmt"
  location            = var.location
  resource_group_name = var.workload_resource_group
  address_space       = [var.spoke_mgmt_address_space]
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Subnets
# ---------------------------------------------------------------------------
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet" # exact name required by Azure
  resource_group_name  = var.hub_resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [local.bastion_cidr]
}

resource "azurerm_subnet" "privatelink" {
  name                              = "snet-privatelink"
  resource_group_name               = var.hub_resource_group_name
  virtual_network_name              = azurerm_virtual_network.hub.name
  address_prefixes                  = [local.privatelink_cidr]
  private_endpoint_network_policies = "Enabled" # NSG applies to private endpoints
}

resource "azurerm_subnet" "web" {
  name                            = "snet-web"
  resource_group_name             = var.workload_resource_group
  virtual_network_name            = azurerm_virtual_network.spoke_app.name
  address_prefixes                = [local.web_cidr]
  default_outbound_access_enabled = false
}

resource "azurerm_subnet" "db" {
  name                            = "snet-db"
  resource_group_name             = var.workload_resource_group
  virtual_network_name            = azurerm_virtual_network.spoke_app.name
  address_prefixes                = [local.db_cidr]
  default_outbound_access_enabled = false
}

resource "azurerm_subnet" "mgmt" {
  name                            = "snet-mgmt"
  resource_group_name             = var.workload_resource_group
  virtual_network_name            = azurerm_virtual_network.spoke_mgmt.name
  address_prefixes                = [local.mgmt_cidr]
  default_outbound_access_enabled = false
}

# ---------------------------------------------------------------------------
# Peering (hub <-> each spoke, both directions). Spoke-to-spoke traffic is
# NOT transitive; shared services (private endpoints, Bastion) live in the hub.
# ---------------------------------------------------------------------------
locals {
  spokes = {
    app  = azurerm_virtual_network.spoke_app
    mgmt = azurerm_virtual_network.spoke_mgmt
  }
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each = local.spokes

  name                         = "peer-hub-to-${each.key}"
  resource_group_name          = var.hub_resource_group_name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = each.value.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  for_each = local.spokes

  name                         = "peer-${each.key}-to-hub"
  resource_group_name          = var.workload_resource_group
  virtual_network_name         = each.value.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

# ---------------------------------------------------------------------------
# NSGs - explicit default-deny inbound on every subnet, least-privilege allows
# ---------------------------------------------------------------------------

# Bastion subnet NSG: rule set required by Azure Bastion.
resource "azurerm_network_security_group" "bastion" {
  name                = "nsg-${var.name_base}-bastion"
  location            = var.location
  resource_group_name = var.hub_resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "AllowHttpsInbound"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowGatewayManagerInbound"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowAzureLoadBalancerInbound"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowBastionHostCommunication"
    priority                   = 150
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["8080", "5701"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowSshRdpOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "3389"]
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }
  security_rule {
    name                       = "AllowAzureCloudOutbound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureCloud"
  }
  security_rule {
    name                       = "AllowBastionCommunicationOutbound"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["8080", "5701"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }
  security_rule {
    name                       = "AllowHttpOutbound"
    priority                   = 130
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }
}

# Web subnet: HTTP from the allowed source (via LB), LB health probe, SSH from Bastion only.
resource "azurerm_network_security_group" "web" {
  #checkov:skip=CKV_AZURE_160:Port 80 is the public web entry point behind the Standard LB; source is the allowed_http_source variable (narrow to your IP for the lab). Prod: Front Door/App Gateway WAF + HTTPS.
  name                = "nsg-${var.name_base}-web"
  location            = var.location
  resource_group_name = var.workload_resource_group
  tags                = var.tags

  security_rule {
    name                       = "AllowHttpFromAllowedSource"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = var.allowed_http_source
    destination_address_prefix = local.web_cidr
  }
  security_rule {
    name                       = "AllowAzureLoadBalancerProbe"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowSshFromBastion"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = local.bastion_cidr
    destination_address_prefix = local.web_cidr
  }
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# DB subnet: PostgreSQL only from the web subnet, SSH from Bastion only.
resource "azurerm_network_security_group" "db" {
  name                = "nsg-${var.name_base}-db"
  location            = var.location
  resource_group_name = var.workload_resource_group
  tags                = var.tags

  security_rule {
    name                       = "AllowPostgresFromWeb"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = local.web_cidr
    destination_address_prefix = local.db_cidr
  }
  security_rule {
    name                       = "AllowSshFromBastion"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = local.bastion_cidr
    destination_address_prefix = local.db_cidr
  }
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Private endpoint subnet: HTTPS from the web subnet only.
resource "azurerm_network_security_group" "privatelink" {
  name                = "nsg-${var.name_base}-privatelink"
  location            = var.location
  resource_group_name = var.hub_resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "AllowHttpsFromWeb"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = local.web_cidr
    destination_address_prefix = local.privatelink_cidr
  }
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Management spoke: SSH from Bastion only (placeholder for ops tooling).
resource "azurerm_network_security_group" "mgmt" {
  name                = "nsg-${var.name_base}-mgmt"
  location            = var.location
  resource_group_name = var.workload_resource_group
  tags                = var.tags

  security_rule {
    name                       = "AllowSshFromBastion"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = local.bastion_cidr
    destination_address_prefix = local.mgmt_cidr
  }
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

locals {
  subnet_nsg = {
    bastion     = { subnet_id = azurerm_subnet.bastion.id, nsg_id = azurerm_network_security_group.bastion.id }
    web         = { subnet_id = azurerm_subnet.web.id, nsg_id = azurerm_network_security_group.web.id }
    db          = { subnet_id = azurerm_subnet.db.id, nsg_id = azurerm_network_security_group.db.id }
    privatelink = { subnet_id = azurerm_subnet.privatelink.id, nsg_id = azurerm_network_security_group.privatelink.id }
    mgmt        = { subnet_id = azurerm_subnet.mgmt.id, nsg_id = azurerm_network_security_group.mgmt.id }
  }
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = local.subnet_nsg

  subnet_id                 = each.value.subnet_id
  network_security_group_id = each.value.nsg_id
}

# ---------------------------------------------------------------------------
# Optional route tables (force-tunnel spokes to a future firewall/NVA)
# ---------------------------------------------------------------------------
resource "azurerm_route_table" "spoke" {
  count = var.enable_route_tables ? 1 : 0

  name                          = "rt-${var.name_base}-spokes"
  location                      = var.location
  resource_group_name           = var.workload_resource_group
  bgp_route_propagation_enabled = false
  tags                          = var.tags

  route {
    name                   = "default-to-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.firewall_private_ip
  }
}

resource "azurerm_subnet_route_table_association" "spoke" {
  for_each = var.enable_route_tables ? {
    web  = azurerm_subnet.web.id
    db   = azurerm_subnet.db.id
    mgmt = azurerm_subnet.mgmt.id
  } : {}

  subnet_id      = each.value
  route_table_id = azurerm_route_table.spoke[0].id
}

# ---------------------------------------------------------------------------
# NAT gateway - controlled outbound for web/db (subnets have no default outbound)
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "nat" {
  count = var.enable_nat_gateway ? 1 : 0

  name                = "pip-${var.name_base}-nat"
  location            = var.location
  resource_group_name = var.workload_resource_group
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway" "this" {
  count = var.enable_nat_gateway ? 1 : 0

  name                = "ng-${var.name_base}"
  location            = var.location
  resource_group_name = var.workload_resource_group
  sku_name            = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  count = var.enable_nat_gateway ? 1 : 0

  nat_gateway_id       = azurerm_nat_gateway.this[0].id
  public_ip_address_id = azurerm_public_ip.nat[0].id
}

resource "azurerm_subnet_nat_gateway_association" "this" {
  for_each = var.enable_nat_gateway ? {
    web = azurerm_subnet.web.id
    db  = azurerm_subnet.db.id
  } : {}

  subnet_id      = each.value
  nat_gateway_id = azurerm_nat_gateway.this[0].id
}

# ---------------------------------------------------------------------------
# Azure Bastion (Basic) - browser-based SSH, no public IPs on VMs
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "bastion" {
  count = var.enable_bastion ? 1 : 0

  name                = "pip-${var.name_base}-bastion"
  location            = var.location
  resource_group_name = var.hub_resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "this" {
  count = var.enable_bastion ? 1 : 0

  name                = "bas-${var.name_base}"
  location            = var.location
  resource_group_name = var.hub_resource_group_name
  sku                 = "Basic"
  tags                = var.tags

  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }

  depends_on = [azurerm_subnet_network_security_group_association.this]
}
