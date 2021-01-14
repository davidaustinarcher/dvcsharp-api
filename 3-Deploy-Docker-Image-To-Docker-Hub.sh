#!/bin/bash

echo "Please log in using your Docker Hub credentials to update the container image"
docker login
docker tag dvcsharp:1.0 contrastsecuritydemo/dvcsharp:1.0
docker push contrastsecuritydemo/dvcsharp:1.0
