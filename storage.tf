/**
 * Copyright 2020 Taito United
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

resource "azurerm_storage_account" "project" {
  count                    = length(local.bucketsById) > 0 ? 1 : 0

  name                     = replace("${var.project}-${var.env}", "-", "")
  resource_group_name      = data.azurerm_resource_group.namespace.name
  location                 = data.azurerm_resource_group.namespace.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    project = var.project
    env     = var.env
    purpose = "storage"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "bucket" {
  count                 = length(local.bucketsById)
  name                  = values(local.bucketsById)[count.index].name
  storage_account_name  = azurerm_storage_account.project[0].name
  container_access_type = "private"

  cors_rule {
    allowed_origins = [
      for cors in values(local.bucketsById)[count.index].cors:
      cors.domain
    ]
    allowed_methods = ["GET"]
  }

  lifecycle {
    prevent_destroy = true
  }
}
