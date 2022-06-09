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

provider "azurerm" {
  features {}
}

data "azuread_client_config" "current" {}

locals {

  owners = (
    length(var.owner_object_ids) > 0
    ? var.owner_object_ids
    : [ data.azuread_client_config.current.object_id ]
  )

  serviceAccounts = (
    var.create_service_accounts
    ? coalesce(var.resources.serviceAccounts, [])
    : []
  )

  ingress = defaults(var.resources.ingress, { enabled: false })

  domains = coalesce(var.resources.ingress.domains, [])

  mainDomains = [
    for domain in local.domains:
    join(".",
      slice(
        split(".", domain.name),
        length(split(".", domain.name)) > 2 ? 1 : 0,
        length(split(".", domain.name))
      )
    )
  ]

  services = coalesce(var.resources.services, {})

  servicesById = {
    for id, service in local.services:
    id => merge(service, { id: id })
  }

  uptimeEnabled = coalesce(var.resources.uptimeEnabled, true)
  uptimeTargetsById = {
    for name, service in local.servicesById:
    name => service
    if var.create_uptime_checks && local.uptimeEnabled && service.uptimePath != null
  }

  containersById = {
    for name, service in local.servicesById:
    name => service
    if var.create_containers && service.type == "container"
  }

  functionsById = {
    for name, service in local.servicesById:
    name => service
    if var.create_functions && service.type == "function"
  }

  functionsForPermissionsById = {
    for name, service in local.servicesById:
    name => service
    if var.create_function_permissions && service.type == "function"
  }

  databasesById = {
    for name, service in local.servicesById:
    name => service
    if var.create_databases && (service.type == "pg" || service.type == "mysql")
  }

  redisDatabasesById = {
    for name, service in local.servicesById:
    name => service
    if var.create_in_memory_databases && (service.type == "redis")
  }

  topicsById = {
    for name, service in local.servicesById:
    name => service
    if var.create_topics && service.type == "topic"
  }

  bucketsById = {
    for name, service in local.servicesById:
    name => service
    if var.create_storage_buckets && service.type == "bucket"
  }

  bucketAdminUsers = flatten([
    for bucket in local.bucketsById: [
      for user in [for u in coalesce(bucket.admins, []): u if length(regexall("^user:", u.id)) > 0]:
      {
        key  = "${bucket.name}-${user.id}"
        user = { name: replace(user.id, "/^user:/", "") }
        bucket = bucket
      }
    ]
  ])

  bucketObjectAdminUsers = flatten([
    for bucket in local.bucketsById: [
      for user in [for u in coalesce(bucket.objectAdmins, []): u if length(regexall("^user:", u.id)) > 0]:
      {
        key  = "${bucket.name}-${user.id}"
        user = { name: replace(user.id, "/^user:/", "") }
        bucket = bucket
      }
    ]
  ])

  bucketObjectViewerUsers = flatten([
    for bucket in local.bucketsById: [
      for user in [for u in coalesce(bucket.objectViewers, []): u if length(regexall("^user:", u.id)) > 0]:
      {
        key  = "${bucket.name}-${user.id}"
        user = { name: replace(user.id, "/^user:/", "") }
        bucket = bucket
      }
    ]
  ])

  bucketAdminGroups = flatten([
    for bucket in local.bucketsById: [
      for group in [for u in coalesce(bucket.admins, []): u if length(regexall("^group:", u.id)) > 0]:
      {
        key  = "${bucket.name}-${group.id}"
        group = { name: replace(group.id, "/^group:/", "") }
        bucket = bucket
      }
    ]
  ])

  bucketObjectAdminGroups = flatten([
    for bucket in local.bucketsById: [
      for group in [for u in coalesce(bucket.objectAdmins, []): u if length(regexall("^group:", u.id)) > 0]:
      {
        key  = "${bucket.name}-${group.id}"
        group = { name: replace(group.id, "/^group:/", "") }
        bucket = bucket
      }
    ]
  ])

  bucketObjectViewerGroups = flatten([
    for bucket in local.bucketsById: [
      for group in [for u in coalesce(bucket.objectViewers, []): u if length(regexall("^group:", u.id)) > 0]:
      {
        key  = "${bucket.name}-${group.id}"
        group = { name: replace(group.id, "/^group:/", "") }
        bucket = bucket
      }
    ]
  ])

  bucketQueues = flatten([
    for bucket in local.bucketsById: [
      for queue in coalesce(bucket.queues, []):
      {
        name = queue.name
        events = queue.events
        bucket = bucket
      }
    ]
  ])

  bucketQueuesByName = {
    for queue in local.bucketQueues:
    queue.name => queue
  }

  gatewayFunctionsById = {
    for name, service in local.servicesById:
    name => service
    if var.create_ingress && local.ingress.enabled && service.type == "function" && service.path != null
  }

  gatewayStaticContentsById = {
    for name, service in local.servicesById:
    name => service
    if var.create_ingress && local.ingress.enabled && service.type == "static"
  }

  gatewayRootStaticContentsById = {
    for name, service in local.gatewayStaticContentsById:
    name => service
    if var.create_ingress && local.ingress.enabled && service.path != null && coalesce(service.path, "") == "/"
  }

  gatewayChildStaticContentsById = {
    for name, service in local.gatewayStaticContentsById:
    name => service
    if var.create_ingress && local.ingress.enabled && service.path != null && coalesce(service.path, "") != "/"
  }

  gatewayEnabled = length(concat(
    values(local.gatewayFunctionsById),
    values(local.gatewayStaticContentsById),
  )) > 0

}

data "azurerm_resource_group" "namespace" {
  name = "${var.resource_group}"
}
