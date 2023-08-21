
- az account list
- az account set
- az upgrade to >= 2.51.0 because of "--json-auth"

```az ad sp create-for-rbac --name "GitHub-Service-Account" --role contributor --scopes /subscriptions/ef6ea1fb-82dd-46bb-a72d-f36c20802858 --json-auth ```
                            

https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure?tabs=azure-cli%2Clinux#use-the-azure-login-action-with-a-service-principal-secret

