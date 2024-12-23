terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=4.5.0"
    }
  }
  required_version = ">=1.9.7"
}

provider "azurerm" {
  features  {}   
  subscription_id ="dd868d94-dfef-4a1f-b0d3-f953c98b9c04"
  resource_provider_registrations = "none"
}


# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "ChatAppDeploymentRG2"
  location = "East US"
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "ChatAppVNet22"
  address_space       = ["10.0.0.0/24"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  timeouts {
    create = "30m"  # Increase timeout for creation
    update = "30m"  # Increase timeout for updates
  }
}

# Subnets
resource "azurerm_subnet" "frontend" {
  name                 = "frontend-subnet2"
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/26"]
  resource_group_name  = azurerm_resource_group.rg.name
   depends_on = [azurerm_virtual_network.vnet]
}

resource "azurerm_subnet" "backend" {
  name                 = "backend-subnet2"
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.64/26"]
  resource_group_name  = azurerm_resource_group.rg.name
   depends_on = [azurerm_virtual_network.vnet]
}

resource "azurerm_subnet" "database" {
  name                 = "database-subnet2"
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.128/26"]
  resource_group_name  = azurerm_resource_group.rg.name
   depends_on = [azurerm_virtual_network.vnet]
}

# NSGs
resource "azurerm_network_security_group" "frontend_nsg" {
  name     = "frontend-nsg2"
  location = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "backend_nsg" {
  name     = "backend-nsg2"
  location = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowBackendTraffic"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "database_nsg" {
  name     = "database-nsg2"
  location = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowDatabaseTraffic"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Public IP for Frontend Load Balancer
resource "azurerm_public_ip" "frontend_public_ip" {
  name              = "frontend-public-ip2"
  location          = azurerm_resource_group.rg.location
  allocation_method = "Static"
  resource_group_name = azurerm_resource_group.rg.name
}

# Load Balancers and Probes
# Load Balancers
resource "azurerm_lb" "frontend_lb" {
  name                = "frontend-lb2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  frontend_ip_configuration {
    name                 = "frontendConfig"
    public_ip_address_id = azurerm_public_ip.frontend_public_ip.id
  }
}

resource "azurerm_lb" "backend_lb" {
  name                = "backend-lb2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  frontend_ip_configuration {
    name      = "backendConfig"
    subnet_id = azurerm_subnet.backend.id
  }
}

# Health Probes
resource "azurerm_lb_probe" "frontend_probe" {
  loadbalancer_id     = azurerm_lb.frontend_lb.id
  name                = "frontend-probe"
  protocol            = "Http"
  port                = 80
   request_path        = "/health"
}

resource "azurerm_lb_probe" "backend_probe" {
  loadbalancer_id     = azurerm_lb.backend_lb.id
  name                = "backend-probe"
  protocol            = "Http"
  port                = 8000

  request_path        = "/health"
}

# Backend Pools
resource "azurerm_lb_backend_address_pool" "frontend_pool" {
  loadbalancer_id     = azurerm_lb.frontend_lb.id
  name                = "frontend-backend-pool"
}

resource "azurerm_lb_backend_address_pool" "backend_pool" {
  loadbalancer_id     = azurerm_lb.backend_lb.id
  name                = "backend-backend-pool"
}

# Frontend VMSS with SSH Key
resource "azurerm_linux_virtual_machine_scale_set" "frontend_vmss" {
  name                = "frontend-vmss2"
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard_B1s"
  instances           = 1
  admin_username      = "azureuser"
  resource_group_name = azurerm_resource_group.rg.name
#source_image_id     = "/subscriptions/dd868d94-dfef-4a1f-b0d3-f953c98b9c04/resourceGroups/ChatAppDeploymentRG/providers/Microsoft.Compute/galleries/CorrectedChatAppGallery/images/CorrectedChatappFrontendimgdef/versions/1.0.0"
#   # Security Profile for Trusted Launch
#   secure_boot_enabled = true
# plan {
#     name      = "frontend"            # Use the SKU name
#     publisher = "Aishwarya"           # Use the Publisher name
#     product   = "ubuntu"              # Use the Offer name
#   }
    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "18.04.202401161"
    }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  network_interface {
    name    = "frontend-nic"
    primary = true
    ip_configuration {
      name                          = "frontend-ipconfig"
      subnet_id                     = azurerm_subnet.frontend.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.frontend_pool.id]
    }
  }
  # SSH key-based authentication
  admin_ssh_key {
    username   = "azureuser"
    public_key = data.azurerm_ssh_public_key.my_ssh_key.public_key
  }
}

resource "azurerm_monitor_autoscale_setting" "frontend_autoscale" {
  name                = "frontend-autoscale"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.frontend_vmss.id

  profile {
    name = "AutoscaleProfile"

    capacity {
      minimum = "1"
      maximum = "3"
      default = "1"
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.frontend_vmss.id
        operator           = "GreaterThan"
        threshold          = 70
        time_grain         = "PT5M"
        statistic          = "Average"
        time_window        = "PT5M"             # Required time_window attribute
        time_aggregation   = "Average"           # Required time_aggregation attribute
      }

      scale_action {                               # Scale action block
        direction = "Increase"
         type      = "ChangeCount"                    # Required type attribute
        value     = "1"                           # Change must be a number, not a string
        cooldown  = "PT10M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.frontend_vmss.id
        operator           = "LessThan"
        threshold          = 30
        time_grain         = "PT5M"
        statistic          = "Average"
        time_window        = "PT5M"             # Required time_window attribute
        time_aggregation   = "Average"           # Required time_aggregation attribute
      }

      scale_action {                               # Scale action block
        direction = "Decrease" 
        type      = "ChangeCount"                     # Required type attribute
        value     = "1"                    # Change must be a number, not a string
        cooldown  = "PT10M"
      }
    }
  }
}

# Backend VMSS with SSH Key
resource "azurerm_linux_virtual_machine_scale_set" "backend_vmss" {
  name                = "backend-vmss2"
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard_B1s"
  instances           = 1
  admin_username      = "azureuser"
  resource_group_name = azurerm_resource_group.rg.name
#   source_image_id     = "/subscriptions/dd868d94-dfef-4a1f-b0d3-f953c98b9c04/resourceGroups/ChatAppDeploymentRG/providers/Microsoft.Compute/galleries/CorrectedChatAppGallery/images/CorrectedBackengChatAppimg/versions/1.0.0"  
#   secure_boot_enabled          = true

# plan {
#     name      = "updated"               # SKU name
#     publisher = "Aishwarya"             # Publisher name
#     product   = "ubuntu"                # Offer name
#   }
    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "18.04.202401161"
    }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  network_interface {
    name    = "backend-nic"
    primary = true
    ip_configuration {
      name                          = "backend-ipconfig"
      subnet_id                              = azurerm_subnet.backend.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.backend_pool.id]
    }
  }
  # SSH key-based authentication
  admin_ssh_key {
    username   = "azureuser"
    public_key = data.azurerm_ssh_public_key.my_ssh_key.public_key
  }
}
resource "azurerm_monitor_autoscale_setting" "backend_autoscale" {
  name                = "backend-autoscale"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.backend_vmss.id

  profile {
    name = "backend-autoscale-profile"
    capacity {
      default = 2    # Start with 2 instances
      minimum = 1    # Minimum of 1 VM instance
      maximum = 5    # Maximum of 5 VM instances during scaling
    }

    # Scaling Rule for CPU > 70% (Scale Up)
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.backend_vmss.id
        operator           = "GreaterThan"
        statistic          = "Average"
        threshold          = 70    # Scale up if CPU usage > 70%
        time_grain         = "PT1M"
        time_window        = "PT5M"
        time_aggregation   = "Average"
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"    # Add 1 VM instance
        cooldown  = "PT5M" # Cooldown period of 5 minutes
      }
    }

    # Scaling Rule for CPU < 30% (Scale Down)
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.backend_vmss.id
        operator           = "LessThan"
        statistic          = "Average"
        threshold          = 30    # Scale down if CPU usage < 30%
        time_grain         = "PT1M"
        time_window        = "PT5M"
        time_aggregation   = "Average"
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"    # Remove 1 VM instance
        cooldown  = "PT5M" # Cooldown period of 5 minutes
      }
    }
  }
}

# Data Block for SSH Key stored in Azure
data "azurerm_ssh_public_key" "my_ssh_key" {
  name        = "ChatApp_sshkey"   # Replace with your actual SSH key name in Azure
  #public_key  = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCyMpX9yuDLStJ38Swnb1xt8+KoSGxB9Cxfpk1t4CdljQ0UU/j+ElUYyOODHL72X8D7PsjyU+1XpkrXtusvETbmooL3rg/EvVCD9HMGmEFBLI5CE8cRptudjeuJcAz2C5/HlHFUzKHqvFFwG1zDdBJ25a4ef0BG+JslVbzpBt22p69DwQl9RLEog/mBgSK/K9+4cBBvjuLfGUKHbPG5PvbOXp9iwa/pEtmNScefRxmx8vwyySFyd1T9+XUfqDfN0G7hi2+PupPNwW9muHkl3c5OuVGNe0ZKmVWuv0lqsOo5tWKzXVojB6g7FjZyDi2FsWE5hARWt1ZsDZ2JcLXf4zvjbv0LVLqVI2ZG8BJzddiUPj4uoX+3sJMtD+DODBSSsXUA1fkmD2AyVzKEUBYWgUIcndgEg0rJXBRTUqgqjYf3BNME1t7lsD/BoitfOcVPloTSdk5fW4eJRPgU6+tYCyEkSArlP30Kd5wfFmxZAvuBdxkhxDdX2UqaEADBlFtNBzk= generated-by-azure" 
  resource_group_name = "ChatAppDeploymentRG" # Replace with the resource group name where the SSH key is stored
 # public_key = data.azurerm_ssh_public_key.my_ssh_key.public_key
}


# Database VM with NSG and NIC
resource "azurerm_linux_virtual_machine" "database_vm" {
  name                = "database-vm2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = "Standard_DS1_v2"
  admin_username      = "azureuser"

  admin_ssh_key {
    username   = "azureuser"
    public_key = data.azurerm_ssh_public_key.my_ssh_key.public_key
  }
   
  network_interface_ids = [
    azurerm_network_interface.database_nic.id,
  ]


    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "18.04.202401161"
    }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    
  }

  
}

# Network Interface for Database VM
resource "azurerm_network_interface" "database_nic" {
  name                = "database-nic2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "database-ipconfig"
    subnet_id                     = azurerm_subnet.database.id
    private_ip_address_allocation = "Dynamic"
  }

  # Associate NSG with NIC
  #network_security_group_id = azurerm_network_security_group.database_nsg.id
}

