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
    "CONTRAST__AGENT__LOGGER__LEVEL"          = "INFO"
    "CONTRAST__AGENT__LOGGER__ROLL_DAILY"     = "true"
    "CONTRAST__AGENT__LOGGER__BACKUPS"         = "30"
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