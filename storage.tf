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

resource "azurerm_storage_account" "account" {
  for_each                  = {for item in local.bucketsById: item.name => item}

  name                      = replace(each.value.name, "-", "")
  resource_group_name       = data.azurerm_resource_group.namespace.name
  location                  = coalesce(each.value.location, data.azurerm_resource_group.namespace.location)
  account_kind              = coalesce(each.value.accountKind, "StorageV2")
  account_tier              = coalesce(each.value.accountTier, "Standard")         # Standard, Premium
  account_replication_type  = coalesce(each.value.accountReplicationType, "RAGRS") # LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS
  access_tier               = coalesce(each.value.storageClass, "Hot")             # Hot, Cool
  https_traffic_only_enabled = coalesce(each.value.enableHttpsTrafficOnly, true)
  min_tls_version           = coalesce(each.value.minTlsVersion, "TLS1_2")         # TLS1_0, TLS1_1, TLS1_2
  allow_nested_items_to_be_public  = coalesce(each.value.allowNestedItemsToBePublic, false)
  is_hns_enabled            = coalesce(each.value.isHnsEnabled, false)
  large_file_share_enabled  = coalesce(each.value.largeFileShareEnabled, false)

  tags = {
    project = var.project
    env     = var.env
    purpose = coalesce(each.value.purpose, "undefined")
  }

  dynamic "network_rules" {
    for_each = each.value.networkRules != null ? [ each.value.networkRules ] : []
    content {
      default_action             = coalesce(network_rules.value.defaultAction, "Deny")
      ip_rules                   = network_rules.value.ipRules
      virtual_network_subnet_ids = network_rules.value.virtualNetworkSubnetIds
    }
  }

  blob_properties {
    dynamic "cors_rule" {
      for_each = coalesce(each.value.corsRules, [])
      content {
        allowed_origins = cors_rule.value.allowedOrigins
        allowed_methods = coalesce(cors_rule.value.allowedMethods, ["GET","HEAD"])
        allowed_headers = coalesce(cors_rule.value.allowedHeaders, ["*"])
        exposed_headers = coalesce(cors_rule.value.exposedHeaders, ["*"])
        max_age_in_seconds = coalesce(cors_rule.value.maxAgeSeconds, 5)
      }
    }

    dynamic "delete_retention_policy" {
      for_each = each.value.versioningRetainDays != null ? [ each.value.versioningRetainDays ] : []
      content {
        days = delete_retention_policy.value
      }
    }

    dynamic "container_delete_retention_policy" {
      for_each = each.value.versioningRetainDays != null ? [ each.value.versioningRetainDays ] : []
      content {
        days = container_delete_retention_policy.value
      }
    }

    versioning_enabled = each.value.versioningEnabled

    # TODO: implement autoDeletionRetainDays
    # TODO: implement transitionRetainDays and transitionStorageClass with azurerm_storage_management_policy
    # TODO: implement backupRetainDays

    # TODO: https://github.com/terraform-providers/terraform-provider-azurerm/issues/8268
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "container" {
  for_each              = {for item in local.bucketsById: item.name => item}

  name                  = each.value.name
  storage_account_name  = azurerm_storage_account.account[each.key].name
  container_access_type = coalesce(each.value.containerAccessType, "private")

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_queue" "bucket_queue" {
  for_each              = {for item in local.bucketQueuesByName: item.name => item}

  name                  = each.value.name
  storage_account_name  = azurerm_storage_account.account[each.value.bucket.name].name
}

resource "azurerm_eventgrid_event_subscription" "bucket_queue" {
  for_each              = {for item in local.bucketQueuesByName: item.name => item}

  name                  = each.value.name
  scope                 = azurerm_storage_account.account[each.value.bucket.name].id
  included_event_types  = each.value.events

  storage_queue_endpoint {
    storage_account_id = azurerm_storage_account.account[each.value.bucket.name].id
    queue_name         = azurerm_storage_queue.bucket_queue[each.key].name
  }
}

/* User permissions */

data "azuread_user" "bucket_admin_user" {
  for_each             = {for item in local.bucketAdminUsers: item.key => item}
  user_principal_name  = each.value.user.name
}

resource "azurerm_role_assignment" "bucket_admin_user_assignment" {
  for_each             = {for item in local.bucketAdminUsers: item.key => item}
  scope                = azurerm_storage_account.account[each.value.bucket.name].id
  principal_id         = data.azuread_user.bucket_admin_user[each.key].object_id
  role_definition_name = "Storage Blob Data Owner"
}

resource "azurerm_role_assignment" "bucket_admin_user_reader_assignment" {
  for_each             = {for item in local.bucketAdminUsers: item.key => item}
  scope                = azurerm_storage_account.account[each.value.bucket.name].id
  principal_id         = data.azuread_user.bucket_admin_user[each.key].object_id
  role_definition_name = "Reader"
}

data "azuread_user" "bucket_object_admin_user" {
  for_each             = {for item in local.bucketObjectAdminUsers: item.key => item}
  user_principal_name  = each.value.user.name
}

resource "azurerm_role_assignment" "bucket_object_admin_user_assignment" {
  for_each             = {for item in local.bucketObjectAdminUsers: item.key => item}
  scope                = azurerm_storage_account.account[each.value.bucket.name].id
  principal_id         = data.azuread_user.bucket_object_admin_user[each.key].object_id
  role_definition_name = "Storage Blob Data Contributor"
}

resource "azurerm_role_assignment" "bucket_object_admin_user_reader_assignment" {
  for_each             = {for item in local.bucketObjectAdminUsers: item.key => item}
  scope                = azurerm_storage_account.account[each.value.bucket.name].id
  principal_id         = data.azuread_user.bucket_object_admin_user[each.key].object_id
  role_definition_name = "Reader"
}

data "azuread_user" "bucket_object_viewer_user" {
  for_each             = {for item in local.bucketObjectViewerUsers: item.key => item}
  user_principal_name  = each.value.user.name
}

resource "azurerm_role_assignment" "bucket_object_viewer_user_assignment" {
  for_each             = {for item in local.bucketObjectViewerUsers: item.key => item}
  scope                = azurerm_storage_account.account[each.value.bucket.name].id
  principal_id         = data.azuread_user.bucket_object_viewer_user[each.key].object_id
  role_definition_name = "Storage Blob Data Reader"
}

resource "azurerm_role_assignment" "bucket_object_viewer_user_reader_assignment" {
  for_each             = {for item in local.bucketObjectViewerUsers: item.key => item}
  scope                = azurerm_storage_account.account[each.value.bucket.name].id
  principal_id         = data.azuread_user.bucket_object_viewer_user[each.key].object_id
  role_definition_name = "Reader"
}

/* Group permissions */

data "azuread_group" "bucket_admin_group" {
  for_each             = {for item in local.bucketAdminGroups: item.key => item}
  display_name         = each.value.group.name
}

resource "azurerm_role_assignment" "bucket_admin_group_assignment" {
  for_each             = {for item in local.bucketAdminGroups: item.key => item}
  scope                = azurerm_storage_account.account[each.value.bucket.name].id
  principal_id         = data.azuread_group.bucket_admin_group[each.key].object_id
  role_definition_name = "Storage Blob Data Owner"
}

resource "azurerm_role_assignment" "bucket_admin_group_reader_assignment" {
  for_each             = {for item in local.bucketAdminGroups: item.key => item}
  scope                = azurerm_storage_account.account[each.value.bucket.name].id
  principal_id         = data.azuread_group.bucket_admin_group[each.key].object_id
  role_definition_name = "Reader"
}

data "azuread_group" "bucket_object_admin_group" {
  for_each             = {for item in local.bucketObjectAdminGroups: item.key => item}
  display_name         = each.value.group.name
}

resource "azurerm_role_assignment" "bucket_object_admin_group_assignment" {
  for_each             = {for item in local.bucketObjectAdminGroups: item.key => item}
  scope                = azurerm_storage_account.account[each.value.bucket.name].id
  principal_id         = data.azuread_group.bucket_object_admin_group[each.key].object_id
  role_definition_name = "Storage Blob Data Contributor"
}

resource "azurerm_role_assignment" "bucket_object_admin_group_reader_assignment" {
  for_each             = {for item in local.bucketObjectAdminGroups: item.key => item}
  scope                = azurerm_storage_account.account[each.value.bucket.name].id
  principal_id         = data.azuread_group.bucket_object_admin_group[each.key].object_id
  role_definition_name = "Reader"
}

data "azuread_group" "bucket_object_viewer_group" {
  for_each             = {for item in local.bucketObjectViewerGroups: item.key => item}
  display_name         = each.value.group.name
}

resource "azurerm_role_assignment" "bucket_object_viewer_group_assignment" {
  for_each             = {for item in local.bucketObjectViewerGroups: item.key => item}
  scope                = azurerm_storage_account.account[each.value.bucket.name].id
  principal_id         = data.azuread_group.bucket_object_viewer_group[each.key].object_id
  role_definition_name = "Storage Blob Data Reader"
}

resource "azurerm_role_assignment" "bucket_object_viewer_group_reader_assignment" {
  for_each             = {for item in local.bucketObjectViewerGroups: item.key => item}
  scope                = azurerm_storage_account.account[each.value.bucket.name].id
  principal_id         = data.azuread_group.bucket_object_viewer_group[each.key].object_id
  role_definition_name = "Reader"
}
