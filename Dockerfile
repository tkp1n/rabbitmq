#escape=`
ARG ERLANG_VERSION=23.0.3
ARG RABBITMQ_VERSION=3.8.8
ARG ERLANG_HOME="C:\erl"
ARG RABBITMQ_HOME="C:\rabbitmq"

#### OTP INSTALLER

FROM mcr.microsoft.com/windows/servercore:ltsc2019 AS otp-installer

ARG ERLANG_VERSION
ARG ERLANG_HOME
ENV ERLANG_VERSION=${ERLANG_VERSION} `
    ERLANG_HOME=${ERLANG_HOME}

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Microsoft Visual C++ 2015 Redistributable is required to run installer and the installed OTP
RUN $url = 'https://download.microsoft.com/download/0/6/4/064F84EA-D1DB-4EAA-9A5C-CC2F0FF6A638/vc_redist.x64.exe'; `
    Write-Host ('Downloading {0} ...' -f $url); `
    Invoke-WebRequest $url -OutFile 'C:\vc_redist.x64.exe'; `
    `
    Write-Host 'Installing Microsoft Visual C++ 2015 Redistributable ...'; `
    Start-Process 'C:\vc_redist.x64.exe' -ArgumentList '/install', '/quiet', '/norestart' -NoNewWindow -Wait; `
    `
    Write-Host 'Cleanup Microsoft Visual C++ 2015 Redistributable installation ...'; `
    Remove-Item 'C:\vc_redist.x64.exe' -Force

RUN $url = 'http://erlang.org/download/otp_win64_{0}.exe' -f $env:ERLANG_VERSION; `
    Write-Host ('Downloading {0} ...' -f $url); `
    Invoke-WebRequest $url -OutFile 'c:\otp.exe'; `
    `
    Write-Host 'Installing OTP ...'; `
    Start-Process 'c:\otp.exe' -ArgumentList '/S', ('/D={0}' -f $env:ERLANG_HOME) -NoNewWindow -Wait; `
    `
    Write-Host 'Cleanup OTP installation ...'; `
    Remove-Item 'c:\otp.exe' -Force

#### RABBIT INSTALLER

FROM mcr.microsoft.com/windows/servercore:ltsc2019 AS rabbit-installer

ARG RABBITMQ_VERSION
ARG RABBITMQ_HOME
ENV RABBITMQ_VERSION=${RABBITMQ_VERSION} `
    RABBITMQ_HOME=${RABBITMQ_HOME}

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

RUN $url = 'https://github.com/rabbitmq/rabbitmq-server/releases/download/v{0}/rabbitmq-server-windows-{0}.zip' -f $env:RABBITMQ_VERSION; `
    Write-Host ('Downloading {0} ...' -f $url); `
    Invoke-WebRequest $url -OutFile 'c:\rabbit.zip'; `
    `
    Write-Host 'Unzipping RabbitMQ ...'; `
    Expand-Archive -Path 'c:\rabbit.zip' -DestinationPath C:\; `
    Move-Item "C:\rabbitmq_server-$env:RABBITMQ_VERSION" $env:RABBITMQ_HOME; `
    `
    Write-Host 'Cleanup RabbitMQ installation ...'; `
    Remove-Item rabbit.zip -Force

#### FINAL IMAGE

FROM mcr.microsoft.com/windows/nanoserver:1809

ARG ERLANG_VERSION
ARG RABBITMQ_VERSION
ARG ERLANG_HOME
ARG RABBITMQ_HOME

ENV ERLANG_VERSION=${ERLANG_VERSION} `
    ERLANG_HOME=${ERLANG_HOME} `
    HOMEDRIVE=C:\ `
    HOMEPATH=data `
    RABBITMQ_VERSION=${RABBITMQ_VERSION} `
    RABBITMQ_HOME=${RABBITMQ_HOME} `
    RABBITMQ_CONFIG_FILE=${RABBITMQ_HOME}\rabbitmq `
    RABBITMQ_LOGS=- `
    RABBITMQ_SASL_LOGS=- `
    RABBITMQ_BASE="C:\data"

COPY --from=otp-installer ${ERLANG_HOME} ${ERLANG_HOME}

ARG SYSTEM="C:\windows\system32\"
COPY --from=otp-installer [ `
     "${SYSTEM}mfc140.dll", `
     "${SYSTEM}mfc140u.dll", `
     "${SYSTEM}mfcm140.dll", `
     "${SYSTEM}mfcm140u.dll", `
     "${SYSTEM}vcamp140.dll", `
     "${SYSTEM}vccorlib140.dll", `
     "${SYSTEM}vcomp140.dll", `
     "${SYSTEM}msvcp140.dll", `
     "${SYSTEM}vcruntime140.dll", `
     "${SYSTEM}concrt140.dll", `
     "${SYSTEM}" ]

WORKDIR ${RABBITMQ_HOME}

COPY --from=rabbit-installer ${RABBITMQ_HOME} .
COPY rabbitmq.config run.cmd .\
COPY .erlang.cookie 'c:\data\.erlang.cookie'

RUN mkdir c:\Users\%USERNAME%\AppData\Roaming\RabbitMQ

EXPOSE 15691 15692 25672 4369 5671 5672 15671 15672 61613 61614 1883 8883 15674 15675

CMD run.cmd