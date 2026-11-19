# ---------------------------------------------------------------------------
# Public Standard Load Balancer -> web VMs (HTTP 80, health probe)
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "lb" {
  name                = "pip-${var.name_base}-lb"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_lb" "web" {
  name                = "lb-${var.name_base}-web"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                 = "fe-public"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "web" {
  name            = "be-web"
  loadbalancer_id = azurerm_lb.web.id
}

resource "azurerm_lb_probe" "http" {
  name                = "probe-http"
  loadbalancer_id     = azurerm_lb.web.id
  protocol            = "Http"
  port                = 80
  request_path        = "/health"
  interval_in_seconds = 15
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "http" {
  name                           = "rule-http"
  loadbalancer_id                = azurerm_lb.web.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "fe-public"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web.id]
  probe_id                       = azurerm_lb_probe.http.id
  disable_outbound_snat          = true # outbound handled by the NAT gateway
}

# ---------------------------------------------------------------------------
# Web tier
# ---------------------------------------------------------------------------
resource "azurerm_network_interface" "web" {
  count = var.web_vm_count

  name                = "nic-${var.name_base}-web-${count.index + 1}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = var.web_subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "web" {
  count = var.web_vm_count

  network_interface_id    = azurerm_network_interface.web[count.index].id
  ip_configuration_name   = "ipconfig"
  backend_address_pool_id = azurerm_lb_backend_address_pool.web.id
}

resource "azurerm_linux_virtual_machine" "web" {
  #checkov:skip=CKV_AZURE_50:No VM extensions are installed; Checkov flags allow_extension_operations default. Prod: install AMA via Azure Policy.
  count = var.web_vm_count

  name                            = "vm-${var.name_base}-web-${count.index + 1}"
  location                        = var.location
  resource_group_name             = var.resource_group_name
  size                            = var.web_vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.web[count.index].id]
  custom_data                     = base64encode(file("${path.module}/cloud-init/web.yaml"))
  tags                            = merge(var.tags, { role = "web" })

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  boot_diagnostics {} # managed storage account
}

# ---------------------------------------------------------------------------
# DB tier - private subnet, no public IP, not in the LB pool
# ---------------------------------------------------------------------------
resource "azurerm_network_interface" "db" {
  name                = "nic-${var.name_base}-db"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = var.db_subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "db" {
  #checkov:skip=CKV_AZURE_50:No VM extensions are installed; Checkov flags allow_extension_operations default. Prod: install AMA via Azure Policy.
  name                            = "vm-${var.name_base}-db"
  location                        = var.location
  resource_group_name             = var.resource_group_name
  size                            = var.db_vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.db.id]
  custom_data = base64encode(templatefile("${path.module}/cloud-init/db.yaml.tftpl", {
    web_subnet_cidr = var.web_subnet_cidr
  }))
  tags = merge(var.tags, { role = "db" })

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  boot_diagnostics {}
}

# ---------------------------------------------------------------------------
# Managed identity RBAC - no secrets on the VMs
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "web_blob_reader" {
  count = var.web_vm_count

  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_linux_virtual_machine.web[count.index].identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "web_kv_secrets_user" {
  count = var.web_vm_count

  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.web[count.index].identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

# ---------------------------------------------------------------------------
# Auto-shutdown (cost guardrail)
# ---------------------------------------------------------------------------
locals {
  all_vm_ids = merge(
    { for i, vm in azurerm_linux_virtual_machine.web : "web-${i + 1}" => vm.id },
    { db = azurerm_linux_virtual_machine.db.id }
  )
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "this" {
  for_each = local.all_vm_ids

  virtual_machine_id    = each.value
  location              = var.location
  enabled               = true
  daily_recurrence_time = var.auto_shutdown_time
  timezone              = var.auto_shutdown_timezone
  tags                  = var.tags

  notification_settings {
    enabled = false
  }
}
