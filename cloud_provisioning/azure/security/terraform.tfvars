# common variables
environment = "development"
location    = "westus2"

# Authentication azure-subscription-id = ""
azure-client-id       = ""
azure-client-secret   = ""
azure-tenant-id       = ""

# key vault
kv-full-object-id =""
kv-read-object-id =""
kv-secrets = {
  sqldb = {
    value = "" # setting to "" will auto-generate the password
  }
  webadmin = {
    value = "hLDmexfL8@m46Suevb!oao"
  }
}