#!/bin/bash
#Remove the current database
rm ./tmp/DVCSharp.db
rm ./bin/Debug/netcoreapp2.1/publish/tmp/DVCSharp.db

#Create a fresh database
dotnet ef database update

#Publish the app
dotnet publish

#Create a zip for the deployment
cd ./bin/Debug/netcoreapp2.1/publish/
zip -r -X "deploy.zip" ./*

#Deploy the app
az webapp deployment source config-zip --resource-group $resourcegroupname --name $webappname --src ./deploy.zip

echo "Deploy complete."
