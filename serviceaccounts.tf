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

# Service accounts

resource "azuread_application" "service_account" {
  for_each                   = {for item in local.serviceAccounts: item.id => item}

  display_name               = each.value.id
  identifier_uris            = ["http://${each.value.id}"]
  available_to_other_tenants = false
  oauth2_allow_implicit_flow = true
}

resource "azuread_service_principal" "service_account" {
  for_each       = {for item in local.serviceAccounts: item.id => item}

  application_id = azuread_application.service_account[each.value.id].application_id
}

# CI/CD

resource "azuread_application" "cicd" {
  count                      = var.create_cicd_service_account ? 1 : 0

  display_name               = "${var.project}-${var.env}-cicd"
  identifier_uris            = ["http://${var.project}-${var.env}-cicd"]
  available_to_other_tenants = false
  oauth2_allow_implicit_flow = true
}

resource "azuread_service_principal" "cicd" {
  count          = var.create_cicd_service_account ? 1 : 0

  application_id = azuread_application.cicd[0].application_id
}
