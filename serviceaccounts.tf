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
  owners                     = local.owners
  identifier_uris            = var.cicd_oauth2_scope_id != "" ? ["http://${each.value.id}"] : null
}

resource "azuread_service_principal" "service_account" {
  for_each       = {for item in local.serviceAccounts: item.id => item}

  application_id = azuread_application.service_account[each.value.id].application_id
  owners         = local.owners
}

# CI/CD

resource "azuread_application" "cicd" {
  count                      = var.create_cicd_service_account ? 1 : 0

  display_name               = "${var.project}-${var.env}-cicd"
  owners                     = local.owners
  identifier_uris            = var.cicd_oauth2_scope_id != "" ? ["http://${var.project}-${var.env}-cicd"] : null

  // For backwards compatibility
  // TODO: remove
  dynamic "api" {
    for_each = var.cicd_oauth2_scope_id != "" ? [ 1 ] : []
    content {
      mapped_claims_enabled          = false
      requested_access_token_version = 1

      known_client_applications      = []

      oauth2_permission_scope {
        admin_consent_description  = "Allow the application to access ${var.project}-${var.env}-cicd on behalf of the signed-in user."
        admin_consent_display_name = "Access ${var.project}-${var.env}-cicd"
        enabled                    = true
        id                         = var.cicd_oauth2_scope_id
        type                       = "User"
        user_consent_description   = "Allow the application to access ${var.project}-${var.env}-cicd on your behalf."
        user_consent_display_name  = "Access ${var.project}-${var.env}-cicd"
        value                      = "user_impersonation"
      }
    }
  }

  // For backwards compatibility
  // TODO: remove
  dynamic "web" {
    for_each = var.cicd_oauth2_scope_id != "" ? [ 1 ] : []
    content {
      redirect_uris = []

      implicit_grant {
        access_token_issuance_enabled = true
        id_token_issuance_enabled     = true
      }
    }
  }
}

resource "azuread_service_principal" "cicd" {
  count          = var.create_cicd_service_account ? 1 : 0

  application_id = azuread_application.cicd[0].application_id
  owners         = local.owners
}
