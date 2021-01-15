output "fqdn" {
  value = "https://${azurerm_app_service.app.default_site_hostname}"
}

output "contrast" {
  value = "This app should appear in the environment ${data.external.yaml.result.url}"
}

output "waf_fqdn" {
  value = "http://${azurerm_public_ip.waf[0].fqdn}"
}
