/**
 * Copyright 2021 Taito United
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

# TODO: Service account role assignments

# CI/CD

resource "azurerm_role_assignment" "cicd_kubernetes_user" {
  count                = var.create_cicd_service_account && var.kubernetes_name != "" ? 1 : 0

  scope                = "/subscriptions/${var.subscription_id}/resourcegroups/${var.resource_group}/providers/Microsoft.ContainerService/managedClusters/${var.kubernetes_name}"
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = azuread_service_principal.cicd[0].id
}

resource "azurerm_role_assignment" "cicd_acr_push" {
  count                = var.create_cicd_service_account ? 1 : 0

  scope                = "/subscriptions/${var.subscription_id}/resourcegroups/${var.resource_group}"
  role_definition_name = "AcrPush"
  principal_id         = azuread_service_principal.cicd[0].id
}

resource "azurerm_role_assignment" "cicd_acr_pull" {
  count                = var.create_cicd_service_account ? 1 : 0

  scope                = "/subscriptions/${var.subscription_id}/resourcegroups/${var.resource_group}"
  role_definition_name = "AcrPull"
  principal_id         = azuread_service_principal.cicd[0].id
}
