#Terraform Deployment Script for Microsoft Azure
#https://www.terraform.io/docs/providers/azurerm/index.html

# Configure the Azure Provider and the version
provider "azurerm" {
  version = "=1.38.0"
}

#create devops project which is used for repository, build and pipelineing for spider indexer
resource "azuredevops_project" "spider_devops_project" {
  project_name = "spider_indexer"
  description  = "DevOps project for spider_indexer"
}

#create devops project which is used for repository, build and pipelineing front-end
resource "azuredevops_project" "front-end_devops_project" {
  project_name = "front-end"
  description  = "DevOps project for front-end"
}

#create devops repository for spider indexer source code
resource "azuredevops_azure_git_repository" "spider_indexer_repository" {
  project_id = azuredevops_project.spider_devops_project.spider_indexer
  name       = "spider_indexer"

  initialization {
    init_type = "Clean"
  }
}

#create devops repository for front-end source code
resource "azuredevops_azure_git_repository" "front-end_repository" {
  project_id = azuredevops_project.front-end_devops_project.front-end
  name       = "front-end"

  initialization {
    init_type = "Clean"
  }
}

#create devops build definition for spider indexer repository and pipeline
resource "azuredevops_build_definition" "spider_indexer_build_def" {
  project_id = azuredevops_project.spider_devops_project.spider_indexer
  name       = "spider_indexer_build"
  path       = "\"

  repository {
    repo_type   = "TfsGit"
    repo_name   = azuredevops_azure_git_repository.spider_indexer_repository.spider_indexer.name        #Build project uses spider indexer repo as source
    branch_name = azuredevops_azure_git_repository.spider_indexer_repository.default_branch.name         #yml filename contains all the relevant build and test commands to carry out
    yml_path    = "azure-pipelines.yml"                                                             #similar to gitlab-ci.yml and buildspec.yml for aws pipelining
  }
}

#create devops build definition for front-end repository and pipeline
resource "azuredevops_build_definition" "front-end_build_def" {
  project_id = azuredevops_project.front-end_devops_project.front-end
  name       = "front-end_build"
  path       = "\"

  repository {
    repo_type   = "TfsGit"
    repo_name   = azuredevops_azure_git_repository.front-end_repository.front-end.name           #Build project uses front-end repo as source
    branch_name = azuredevops_azure_git_repository.front-end_repository.default_branch.name         #yml filename contains all the relevant build and test commands to carry out
    yml_path    = "azure-pipelines.yml"                                                             #similar to gitlab-ci.yml and buildspec.yml for aws pipelining
  }
}

#Data element created for devops role
data "azurerm_subscription" "devops" {}

#https://docs.microsoft.com/en-us/azure/role-based-access-control/resource-provider-operations#microsoftaad - Azure Resource Manager Resource Provider operations
#Link provides list of all possible actions roles can do
#Role created for Devops to ensure only specified users have the access rights to edit, add, remove any components in the repo, build projects or devops pipeline
resource "azurerm_role_definition" "dev_ops_role_def" {
  name        = "dev_ops-role"
  scope       = "${data.azurerm_subscription.primary.devops}"
  description = "Role created for azure devops"

#Microsoft.Resources/subscriptions/resourceGroups/read
  permissions {                                                                 #Permissions in role allow for creation, deletion & modification of the above devops components
    actions     = ["Microsoft.DataFactory/datafactories/datapipelines/write",
        "Microsoft.DataFactory/datafactories/datapipelines/update/action",
        "Microsoft.DataFactory/datafactories/datapipelines/resume/action",
        "Microsoft.DataFactory/datafactories/datapipelines/read",
	      "Microsoft.DataFactory/datafactories/datapipelines/pause/action",
        "Microsoft.DataFactory/datafactories/datapipelines/delete",
        "Microsoft.DataFactory/locations/configureFactoryRepo/action"
    ]
  }

}

#monitoring storage account for logs from devops
resource "azurerm_storage_account" "devops_storage" {
  name                     = "devops_storage_account"
  resource_group_name      = "${azurerm_resource_group.main.main_resoucre_group}"
  location                 = "${azurerm_resource_group.main.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

#Azure monitor to monitor and log activity from devops service
resource "azurerm_monitor_activity_log_alert" "main" {
  name                = "devops-alert"
  resource_group_name = "${azurerm_resource_group.main.name}"
  scopes              = ["${azurerm_resource_group.main.id}"]
  description         = "This alert will monitor and log things from the devops service."

  criteria {
    resource_id    = "${azurerm_storage_account.devops_storage.id}"
    operation_name = "Microsoft.Storage/devops/write"
  }

  action {
    action_group_id = "${azurerm_monitor_action_group.main.id}"

    webhook_properties = {
      from = "terraform"
    }
  }
}

#create main resource group sets location at which resource will be created
resource "azurerm_resource_group" "main" {
  name     = "main_resoucre_group"
  location = "UK West"
}

#create domain for eventgrid service
resource "azurerm_eventgrid_domain" "eventgrid_domain" {
  name                = "eventgrid-domain"
  location            = "${azurerm_resource_group.main_resoucre_group.location}"
  resource_group_name = "${azurerm_resource_group.main_resoucre_group.name}"

  tags = {
    environment = "Dev"
  }
}

#create eventgrid topic and assign it to the main resource group and location
resource "azurerm_eventgrid_topic" "main_eventgrid_topic" {
  name                = "devops-eventgrid-topic"
  location            = "${azurerm_resource_group.main_resoucre_group.location}"
  resource_group_name = "${azurerm_resource_group.main_resoucre_group.name}"

  tags = {
    environment = "Development"
  }
}

#storage account for front_end and spider indexer function blob storage
resource "azurerm_storage_account" "main_storage_account" {
  name                     = "storage_account"
  resource_group_name      = "${azurerm_resource_group.main.main_resoucre_group}"
  location                 = "${azurerm_resource_group.main.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

#create storage container assigned to storage account for front end and spider indexer blobs
resource "azurerm_storage_container" "main_storage_container" {
  name                  = "storage_container"
  resource_group_name   = "${azurerm_resource_group.main.main_resoucre_group}"
  storage_account_name  = "${azurerm_storage_account.main_storage_account.storage_account}"
  container_access_type = "public"
}

#create blob storage for spider indexer source code
resource "azurerm_storage_blob" "spider_indexer" {
  name                   = "spider_indexer"
  resource_group_name    = "${azurerm_resource_group.main.main_resoucre_group}"
  storage_account_name   = "${azurerm_storage_account.main_storage_account.storage_account}"
  storage_container_name = "${azurerm_storage_container.main_storage_container.storage_container}"
  type                   = "Block"
}

#create blob storage for front end source code
resource "azurerm_storage_blob" "front-end" {
  name                   = "front-end"
  resource_group_name    = "${azurerm_resource_group.main.main_resoucre_group}"
  storage_account_name   = "${azurerm_storage_account.main_storage_account.storage_account}"
  storage_container_name = "${azurerm_storage_container.main_storage_container.storage_container}"
  type                   = "Block"
}

#create app service for lambda function, determines the instance size, capacity etc which the function runs on
resource "azurerm_app_service_plan" "main_appservice" {
  name                = "spider-indexer-azure-function-service-plan"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.main_resoucre_group}"

  sku {
    tier = "Standard"
    size = "S1"
  }
}

#create spider indexer azure function
resource "azurerm_function_app" "spider_indexer" {
  name                      = "spider_indexer"
  location                  = "${azurerm_resource_group.main.location}"
  resource_group_name       = "${azurerm_resource_group.main_resoucre_group.name}"
  app_service_plan_id       = "${azurerm_app_service_plan.main_appservice.name}"
  storage_connection_string = "${azurerm_storage_account.main_storage_account.primary_connection_string}"

  connection_string {
      type = "APIHub"           #initiated via API
  }
}

#create api managment for spider indexer api
resource "azurerm_api_management" "main_spider_apimanagement" {
  name                = "spider_indexer_apimanagement"
  location            = "${azurerm_resource_group.main_resoucre_group.location}"
  resource_group_name = "${azurerm_resource_group.main_resoucre_group.name}"
  publisher_name      = ""
  publisher_email     = ""
}

#create api to execute the spider indexer function
resource "azurerm_api_management_api" "main_spider_api" {
  name                = "spider_indexer_api"
  resource_group_name = "${azurerm_resource_group.main_resoucre_group.name}"
  api_management_name = "${azurerm_api_management.main_spider_apimanagement.name}"
  revision            = "1"
  display_name        = "Spider Indexer API"
  path                = "spider_api"
  protocols           = ["https"]
}

#create api management for main search api
resource "azurerm_api_management" "main_search_apimanagement" {
  name                = "search_apimanagement"
  location            = "${azurerm_resource_group.main_resoucre_group.location}"
  resource_group_name = "${azurerm_resource_group.main_resoucre_group.name}"
  publisher_name      = ""
  publisher_email     = ""
}

#create api which calls the search service that then searches through the spider indexer DB and returns to front-end
resource "azurerm_api_management_api" "search_api" {
  name                = "search_api"
  resource_group_name = "${azurerm_resource_group.main_resoucre_group.name}"
  api_management_name = "${azurerm_api_management.main_search_apimanagement.name}"
  revision            = "1"
  display_name        = "Search API"
  path                = "search_api"
  protocols           = ["https"]
}

#create api management for ads api
resource "azurerm_api_management" "main_ads_apimanagement" {
  name                = "ads_apimanagement"
  location            = "${azurerm_resource_group.main_resoucre_group.location}"
  resource_group_name = "${azurerm_resource_group.main_resoucre_group.name}"
  publisher_name      = ""
  publisher_email     = ""
}

#create api with calls the search service that then searches through the ads DB and returns to front-end
resource "azurerm_api_management_api" "ads_api" {
  name                = "ads_api"
  resource_group_name = "${azurerm_resource_group.main_resoucre_group.name}"
  api_management_name = "${azurerm_api_management.main_ads_apimanagement.name}"
  revision            = "1"
  display_name        = "Ads API"
  path                = "ads_api"
  protocols           = ["https"]
}

#create search service used to search through spider indexer DB
resource "azurerm_search_service" "spider_search" {
  name                = "search"
  resource_group_name = "${azurerm_resource_group.main_resoucre_group.name}"
  location            = "${azurerm_resource_group.main_resoucre_group.location}"
  sku                 = "standard"            #Instance type

  tags = {
    environment = "development"
    database    = "development"
  }
}

#create search service used to search through ads DB
resource "azurerm_search_service" "ads_search" {
  name                = "ads_search"
  resource_group_name = "${azurerm_resource_group.main_resoucre_group.name}"
  location            = "${azurerm_resource_group.main_resoucre_group.location}"
  sku                 = "standard"    #Instance type

  tags = {
    environment = "development"
    database    = "development"
  }
}

#resource created to produce a random integer for cosmoDB resources
resource "random_integer" "ri" {
  min = 10000
  max = 99999
}

#cosmosDB account required to create cosmoDB tables
#Cosmos account is the fundamental unit of global distribution and high availability.
#For globally distributing your data and throughput across multiple Azure regions, you can add
#and remove Azure regions to your Azure Cosmos account at any time.
resource "azurerm_cosmosdb_account" "cosmoDB_account" {
  name                = "tfex-cosmos-db-${random_integer.ri.result}"
  location            = "${azurerm_resource_group.main_resoucre_group.location}"
  resource_group_name = "${azurerm_resource_group.main_resoucre_group.name}"
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  enable_automatic_failover = true

  consistency_policy {
    consistency_level       = "BoundedStaleness"
    max_interval_in_seconds = 10
    max_staleness_prefix    = 200
  }

  geo_location {
    location          = "${var.failover_location}"          #failover if database fails, ensures max availability of DB
    failover_priority = 1
  }

  geo_location {
    prefix            = "tfex-cosmos-db-${random_integer.ri.result}-customid"
    location          = "${azurerm_resource_group.main_resoucre_group.location}"
    failover_priority = 0
  }
}

#create instance of cosmoDB account for spider indexer table
data "azurerm_cosmosdb_account" "search_cosmodb_account" {
  name                = "search_cosmodb_account"
  resource_group_name = "search_cosmodb_resource_group"
}

#create instance of cosmoDB account for ads table
data "azurerm_cosmosdb_account" "ads_cosmodb_account" {
  name                = "ads_cosmodb_account"
  resource_group_name = "ads_cosmodb_resource_group"
}

#creating cosmoDB table for spider indexer
resource "azurerm_cosmosdb_table" "main_spider_cosmodb_table" {
  name                = "spider_cosmodb_table"
  resource_group_name = "${data.azurerm_cosmosdb_account.search_cosmodb_account.resource_group_name}"
  account_name        = "${data.azurerm_cosmosdb_account.search_cosmodb_account.name}"
}

#creating cosmoDB table for ads
resource "azurerm_cosmosdb_table" "main_ads_cosmodb_table" {
  name                = "ads_cosmodb_table"
  resource_group_name = "${data.azurerm_cosmosdb_account.ads_cosmodb_account.resource_group_name}"
  account_name        = "${data.azurerm_cosmosdb_account.ads_cosmodb_account.name}"
}

#create action group for monitoring service
resource "azurerm_monitor_action_group" "main_monitor_action_group" {
  name                = "monitor_action_group"
  resource_group_name = "${azurerm_resource_group.main_resoucre_group.resource_group_name}"
  short_name          = "p0action"

  email_receiver {
    name                    = "send_via_email"
    email_address           = "amckenna41@qub.ac.uk"        #destination for any alerts/events/alarms
    use_common_alert_schema = true
  }
}

#https://docs.microsoft.com/en-gb/azure/azure-monitor/platform/metrics-supported
#create monitoring for cosmoDB instance, resource connnected to monitoring action group which is triggered if metric threshold reached
resource "azurerm_monitor_metric_alert" "main_cosmodb_monitor" {
  name                = "cosmodb-metric-alert"
  resource_group_name = "${azurerm_resource_group.main_resoucre_group.resource_group_name}"
  scopes              = ["${azurerm_cosmosdb_table.main_spider_cosmodb_table.name}"]
  description         = "Metric monitors the number of writes to the cosmosdb table, if number of writes exceeds threshold alert is triggered and sent to action group."
  frequency           = PT1H

  criteria {
    metric_namespace = "Microsoft.DocumentDB/databaseAccounts"
    metric_name      = "IndexUsage"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 30

  }

  action {
    action_group_id = "${azurerm_monitor_action_group.main_monitor_action_group.name}"
  }
}
