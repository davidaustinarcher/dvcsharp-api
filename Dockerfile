FROM  mcr.microsoft.com/dotnet/core/sdk:2.1
LABEL MAINTAINER "Appsecco"

ENV ASPNETCORE_URLS=http://0.0.0.0:5000

COPY . /app

WORKDIR /app

#Add in the contrast sensors
RUN dotnet add  "dvcsharp-core-api.csproj" package Contrast.SensorsNetCore --package-directory ./contrast 

RUN dotnet restore \
    && dotnet ef database update

#Set the environment vars to enable the agent
ENV CORECLR_PROFILER_PATH_64 ./contrast/contrast.sensorsnetcore/1.7.2/contentFiles/any/netstandard2.0/contrast/runtimes/linux-x64/native/ContrastProfiler.so
ENV CORECLR_PROFILER {8B2CE134-0948-48CA-A4B2-80DDAD9F5791}
ENV CORECLR_ENABLE_PROFILING 1
ENV CONTRAST_CORECLR_LOGS_DIRECTORY /opt/contrast/

ENV CONTRAST__APPLICATION__NAME dvcsharp-api
ENV CONTRAST__SERVER__NAME docker
ENV CONTRAST__SERVER__ENVIRONMENT qa

EXPOSE 5000

CMD ["dotnet", "run"]
