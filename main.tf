#Terraform `provider` section is required since the `azurerm` provider update to 2.0+
provider "azurerm" {
}

#Extract the connection from the normal yaml file to pass to the app container
data "external" "yaml" {
  program = [var.python_binary, "${path.module}/parseyaml.py"]
}

#Set up a personal resource group for the SE local to them
resource "azurerm_resource_group" "personal" {
  name     = "Sales-Engineer-${var.initials}"
  location = var.location
}

#Set up an app service plan
resource "azurerm_app_service_plan" "app" {
  name                = "${replace(var.appname, "/[^-0-9a-zA-Z]/", "-")}-${var.initials}-serviceplan"
  location            = azurerm_resource_group.personal.location
  resource_group_name = azurerm_resource_group.personal.name

  sku {
    tier = "Standard"
    size = "S1"
  }
}

#Set up an app service
resource "azurerm_app_service" "app" {
  name                = "${replace(var.appname, "/[^-0-9a-zA-Z]/", "-")}-${var.initials}-app-service"
  location            = azurerm_resource_group.personal.location
  resource_group_name = azurerm_resource_group.personal.name
  app_service_plan_id = azurerm_app_service_plan.app.id

  site_config {
    always_on = true
  }

  app_settings = {
    "ASPNETCORE_ENVIRONMENT"                    = "Production"
    "CORECLR_ENABLE_PROFILING"                  = "1"
    "CORECLR_PROFILER"                          = "{8B2CE134-0948-48CA-A4B2-80DDAD9F5791}"
    "CORECLR_PROFILER_PATH_32"                  = "D:\\home\\SiteExtensions\\Contrast.NetCore.Azure.SiteExtension\\ContrastNetCoreAppService\\runtimes\\win-x32\\native\\ContrastProfiler.dll"
    "CORECLR_PROFILER_PATH_64"                  = "D:\\home\\SiteExtensions\\Contrast.NetCore.Azure.SiteExtension\\ContrastNetCoreAppService\\runtimes\\win-x32\\native\\ContrastProfiler.dll"
    "CONTRAST_DATA_DIRECTORY"                   = "D:\\home\\SiteExtensions\\Contrast.NetCore.Azure.SiteExtension\\ContrastNetCoreAppService\\runtimes\\win-x32\\native\\"
    "CONTRAST__API__URL"                        = data.external.yaml.result.url
    "CONTRAST__API__USER_NAME"                  = data.external.yaml.result.user_name
    "CONTRAST__API__SERVICE_KEY"                = data.external.yaml.result.service_key
    "CONTRAST__API__API_KEY"                    = data.external.yaml.result.api_key
    "CONTRAST__APPLICATION__NAME"               = var.appname
    "CONTRAST__SERVER__NAME"                    = var.servername
    "CONTRAST__SERVER__ENVIRONMENT"             = var.environment
    "CONTRAST__APPLICATION__SESSION_METADATA"   = var.session_metadata
    "CONTRAST__SERVER__TAGS"                    = var.servertags
    "CONTRAST__APPLICATION__TAGS"               = var.apptags
    "CONTRAST__AGENT__LOGGER__LEVEL"            = "INFO"
    "CONTRAST__AGENT__LOGGER__ROLL_DAILY"       = "true"
    "CONTRAST__AGENT__LOGGER__BACKUPS"          = "30"


  }

  provisioner "local-exec" {
    command     = "./deploy.sh"
    working_dir = path.module

    environment = {
      webappname        = "${replace(var.appname, "/[^-0-9a-zA-Z]/", "-")}-${var.initials}-app-service"
      resourcegroupname = azurerm_resource_group.personal.name
    }
  }
}

resource "azurerm_template_deployment" "extension" {
  name                = "extension"
  resource_group_name = azurerm_app_service.app.resource_group_name
  template_body       = file("siteextensions.json")

  parameters = {
    "siteName"          = azurerm_app_service.app.name
    "extensionName"     = "Contrast.NetCore.Azure.SiteExtension"   

  }

  deployment_mode     = "Incremental"

  #restart the app service after installing the extension
  provisioner "local-exec" {
    command     = "az webapp restart --name ${azurerm_app_service.app.name} --resource-group ${azurerm_app_service.app.resource_group_name}"      
  }

}

variable "enable_waf" {
  description = "If set to true, enable auto scaling"
  type        = bool
  default     = true
}

#Set up a vnet for the WAF
resource "azurerm_virtual_network" "waf" {
  name                = "${var.appname}-${var.initials}-vnet"
  resource_group_name = azurerm_resource_group.personal.name
  location            = azurerm_resource_group.personal.location
  address_space       = ["10.254.0.0/16"]
  count               = var.enable_waf ? 1 : 0
}

resource "azurerm_subnet" "frontend" {
  name                 = "frontend"
  resource_group_name  = azurerm_resource_group.personal.name
  virtual_network_name = azurerm_virtual_network.waf[0].name
  address_prefix       = "10.254.0.0/24"
  count                = var.enable_waf ? 1 : 0
}

resource "azurerm_subnet" "backend" {
  name                 = "backend"
  resource_group_name  = azurerm_resource_group.personal.name
  virtual_network_name = azurerm_virtual_network.waf[0].name
  address_prefix       = "10.254.2.0/24"
  count                = var.enable_waf ? 1 : 0
}

resource "azurerm_public_ip" "waf" {
  name                = "${var.appname}-${var.initials}-pip"
  resource_group_name = azurerm_resource_group.personal.name
  location            = azurerm_resource_group.personal.location
  allocation_method   = "Dynamic"
  domain_name_label   = "${var.appname}-${var.initials}-waf"
  count               = var.enable_waf ? 1 : 0
}

# since these variables are re-used - a locals block makes this more maintainable
locals {
  backend_address_pool_name      = "${azurerm_virtual_network.waf[0].name}-beap"
  frontend_port_name             = "${azurerm_virtual_network.waf[0].name}-feport"
  frontend_ip_configuration_name = "${azurerm_virtual_network.waf[0].name}-feip"
  http_setting_name              = "${azurerm_virtual_network.waf[0].name}-be-htst"
  listener_name                  = "${azurerm_virtual_network.waf[0].name}-httplstn"
  request_routing_rule_name      = "${azurerm_virtual_network.waf[0].name}-rqrt"
  backend_probe_name             = "${azurerm_virtual_network.waf[0].name}-probe"
}

resource "azurerm_application_gateway" "network" {
  name                = "${var.appname}-${var.initials}-waf"
  resource_group_name = azurerm_resource_group.personal.name
  location            = azurerm_resource_group.personal.location
  count               = var.enable_waf ? 1 : 0

  sku {
    name     = "WAF_Medium"
    tier     = "WAF"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "${var.appname}-${var.initials}-ip-configuration"
    subnet_id = azurerm_subnet.frontend[0].id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.waf[0].id
  }

  backend_address_pool {
    name      = local.backend_address_pool_name
    fqdns     = [azurerm_app_service.app.default_site_hostname]
  }

  probe {
    name                                      = local.backend_probe_name
    protocol                                  = "Http"
    path                                      = "/"
    interval                                  = 30
    timeout                                   = 120
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true
  }

  backend_http_settings {
    name                                = local.http_setting_name
    probe_name                          = local.backend_probe_name
    cookie_based_affinity               = "Disabled"
    path                                = "/"
    port                                = 80
    protocol                            = "Http"
    request_timeout                     = 120
    pick_host_name_from_backend_address = true
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                        = local.request_routing_rule_name
    rule_type                   = "Basic"
    http_listener_name          = local.listener_name
    backend_address_pool_name   = local.backend_address_pool_name
    backend_http_settings_name  = local.http_setting_name
  }

  waf_configuration {
    enabled           = true
    firewall_mode     = "Prevention"
    rule_set_version  = "3.0"
  }
}