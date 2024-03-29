# Azure project resources

Provides Azure resources typically required by projects. The resources are defined in a cloud provider agnostic and developer friendly YAML format. An example:

```
uptimeEnabled: true
backupEnabled: true

auth:
  serviceAccounts: # TODO: implement
    - name: my-project-prod-server
    - name: my-project-prod-worker

ingress:
  class: gateway
  enabled: true
  createMainDomain: false
  domains:
    - name: myproject.mydomain.com
      altName: www.myproject.mydomain.com

services:
  admin:
    type: static # TODO: implement
    path: /admin
    uptimePath: /admin

  client:
    type: static # TODO: implement
    path: /
    uptimePath: /

  server:
    type: function # TODO: implement
    path: /api
    uptimePath: /api/uptimez
    timeout: 3
    runtime: nodejs12.x
    memoryRequest: 128
    secrets:
      SERVICE_ACCOUNT_KEY: my-project-prod-server-serviceaccount.key
      DATABASE_PASSWORD: my-project-prod-app
      REDIS_PASSWORD: ${taito_project}-${taito_env}-redis.secretKey
    env:
      TOPIC_JOBS: my-project-prod-jobs
      DATABASE_HOST: my-postgres.c45t0ln04uqh.us-east-1.rds.amazonaws.com
      DATABASE_PORT: 5432
      DATABASE_SSL_ENABLED: true
      DATABASE_NAME: my-project-prod
      DATABASE_USER: my-project-prod-app
      DATABASE_POOL_MIN: 5
      DATABASE_POOL_MAX: 10
      REDIS_HOST: my-project-prod-001.my-project-prod.nde1c2.use1.cache.amazonaws.com
      REDIS_PORT: 6379
      STORAGE_BUCKET: my-project-prod

  jobs:
    type: topic # TODO: implement
    name: my-project-prod-jobs
    publishers:
      - id: my-project-prod-server
    subscribers:
      - id: my-project-prod-worker

  worker:
    type: container # TODO: implement
    image: my-registry/my-worker:1234
    replicas: 2
    memoryRequest: 128
    secrets:
      SERVICE_ACCOUNT_KEY: my-project-prod-worker-serviceaccount.key
    env:
      TOPIC_JOBS: my-project-prod-jobs
      STORAGE_BUCKET: my-project-prod

  redis:
    type: redis # TODO: implement
    name: my-project-prod
    replicas: 1
    machineType: TODO
    secret: my-project-prod-redis.secretKey

  bucket:
    type: bucket
    name: my-bucket-prod
    location: northeurope
    storageClass: Hot
    corsRules:
      - allowedOrigins:
        - https://myproject.mydomain.com
        - https://www.myproject.mydomain.com
    queues:
      - name: my-bucket-prod
        events:
          - Microsoft.Storage.BlobCreated
          - Microsoft.Storage.BlobDeleted
    # Object lifecycle (TODO: implement)
    versioning: true
    versioningRetainDays: 60
    lockRetainDays: # TODO: implement
    transitionRetainDays: # TODO: implement
    transitionStorageClass: # TODO: implement
    autoDeletionRetainDays: # TODO: implement
    # Replication (TODO: implement)
    replicationBucket:
    # Backup (TODO: implement)
    backupRetainDays: 60
    backupLocation: eu
    backupLock: true
    # User rights
    admins:
      - id: user:john.doe@mydomain.com
    objectAdmins:
      - id: group:Developers
    objectViewers:
      - id: user:jane.doe@mydomain.com
```

With `create_*` variables you can choose which resources are created/updated in which phase. For example, you can choose to update some of the resources manually when the environment is created or updated:

```
  create_storage_buckets        = true
  create_databases              = true
  create_in_memory_databases    = true
  create_topics                 = true
  create_service_accounts       = true
  create_uptime_checks          = true
```

And choose to update gateway, containers, and functions on every deployment in your CI/CD pipeline:

```
  create_ingress                = true
  create_containers             = true
  create_functions              = true
  create_function_permissions   = true
```

Similar YAML format is used also by the following modules:

- [AWS project resources](https://registry.terraform.io/modules/TaitoUnited/project-resources/aws)
- [Azure project resources](https://registry.terraform.io/modules/TaitoUnited/project-resources/azurerm)
- [Google Cloud project resources](https://registry.terraform.io/modules/TaitoUnited/project-resources/google)
- [Digital Ocean project resources](https://registry.terraform.io/modules/TaitoUnited/project-resources/digitalocean)
- [Full-stack template (Helm chart for Kubernetes)](https://github.com/TaitoUnited/taito-charts/tree/master/full-stack)

NOTE: This module creates resources for only one project environment. That is, such resources should already exist that are shared among multiple projects or project environments (e.g. users, roles, vpc networks, kubernetes, database clusters). You can use the following modules to create the shared infrastructure:

- [Admin](https://registry.terraform.io/modules/TaitoUnited/admin/azurerm)
- [DNS](https://registry.terraform.io/modules/TaitoUnited/dns/azurerm)
- [Network](https://registry.terraform.io/modules/TaitoUnited/network/azurerm)
- [Compute](https://registry.terraform.io/modules/TaitoUnited/compute/azurerm)
- [Kubernetes](https://registry.terraform.io/modules/TaitoUnited/kubernetes/azurerm)
- [Databases](https://registry.terraform.io/modules/TaitoUnited/databases/azurerm)
- [Storage](https://registry.terraform.io/modules/TaitoUnited/storage/azurerm)
- [Monitoring](https://registry.terraform.io/modules/TaitoUnited/monitoring/azurerm)
- [Integrations](https://registry.terraform.io/modules/TaitoUnited/integrations/azurerm)
- [PostgreSQL privileges](https://registry.terraform.io/modules/TaitoUnited/privileges/postgresql)
- [MySQL privileges](https://registry.terraform.io/modules/TaitoUnited/privileges/mysql)

> TIP: This module is used by [project templates](https://taitounited.github.io/taito-cli/templates/#project-templates) of [Taito CLI](https://taitounited.github.io/taito-cli/). See the [full-stack-template](https://github.com/TaitoUnited/full-stack-template) as an example on how to use this module.

Contributions are welcome! This module should include support for the most commonly used Azure services. For more specific cases, the YAML can be extended with additional Terraform modules.
