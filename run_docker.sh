docker run -p 5000:5000 \
    -v $PWD/contrast_security.yaml:/etc/contrast/dotnet-core/contrast_security.yaml \
    -v $PWD/logs:/opt/contrast \
    -e CONTRAST__AGENT__LOGGER__LEVEL=trace \
    dvcsharp:1.0

#docker run -p 5000:5000 -v contrast_security.yaml:/etc/contrast/dotnet-core/contrast_security.yaml -v $PWD/logs:/opt/contrast dvcsharp