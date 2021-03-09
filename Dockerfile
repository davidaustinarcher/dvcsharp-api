FROM  mcr.microsoft.com/dotnet/core/sdk:2.1

ENV ASPNETCORE_URLS=http://0.0.0.0:5000
ENV CONTRAST_VERSION=1.8.0

COPY . /app

WORKDIR /app

#Add in the contrast sensors
RUN dotnet add  "dvcsharp-core-api.csproj" package Contrast.SensorsNetCore -v $CONTRAST_VERSION --package-directory ./contrast 

RUN dotnet restore \
    && dotnet ef database update

#Use the development appsettings.Development.json
ENV ASPNETCORE_ENVIRONMENT=Development

#Set the environment vars to enable the agent
ENV CORECLR_PROFILER_PATH_64 ./contrast/contrast.sensorsnetcore/$CONTRAST_VERSION/contentFiles/any/netstandard2.0/contrast/runtimes/linux-x64/native/ContrastProfiler.so
ENV CORECLR_PROFILER {8B2CE134-0948-48CA-A4B2-80DDAD9F5791}
ENV CORECLR_ENABLE_PROFILING 1
ENV CONTRAST_CORECLR_LOGS_DIRECTORY /opt/contrast/
ENV CONTRAST__APPLICATION__NAME dvcsharp-api

EXPOSE 5000

CMD ["dotnet", "run"]
