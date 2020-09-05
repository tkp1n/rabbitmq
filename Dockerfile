ARG OTP_VERSION=23.0.1
ARG RABBITMQ_VERSION=3.8.8

FROM mcr.microsoft.com/windows/servercore:ltsc2019

ARG OTP_VERSION
ARG RABBITMQ_VERSION

ENV OTP_VERSION ${OTP_VERSION}
ENV RABBITMQ_VERSION ${RABBITMQ_VERSION}

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

RUN $url = 'http://erlang.org/download/otp_win64_{0}.exe' -f $env:OTP_VERSION; \
  Write-Host ('Downloading {0} ...' -f $url); \
  Invoke-WebRequest $url -OutFile 'c:\otp.exe'; \
  \
  Write-Host 'Installing OTP ...'; \
  Start-Process 'c:\otp.exe' -ArgumentList '/S' -Wait; \
  \
  Write-Host 'Cleanup OTP installation ...'; \
  Remove-Item 'c:\otp.exe' -Force

ENV ERLANG_HOME "C:\Program Files\erl-$OTP_VERSION"

RUN $url = 'https://github.com/rabbitmq/rabbitmq-server/releases/download/v{0}/rabbitmq-server-{0}.exe' -f $env:RABBITMQ_VERSION ; \
  Write-Host ('Downloading {0} ...' -f $url); \
  Invoke-WebRequest $url -OutFile 'c:\rabbit.exe'; \
  \
	Write-Host 'Installing RabbitMQ ...'; \
  $proc = Start-Process 'c:\rabbit.exe' '/S' -Wait:$false -Passthru; \
  Wait-Process -Id $proc.Id; \
  \
	Write-Host 'Configuring RabbitMQ ...'; \
  # Add management plugin
  $plugins = 'C:\Program Files\RabbitMQ Server\rabbitmq_server-{0}\sbin\rabbitmq-plugins.bat' -f $env:RABBITMQ_VERSION; \
  Start-Process $plugins 'enable rabbitmq_management' -Wait; \
  # Remove Windows Service, as we start the server using the rabbitmq-server.bat below
  $service = 'C:\Program Files\RabbitMQ Server\rabbitmq_server-{0}\sbin\rabbitmq-service.bat' -f $env:RABBITMQ_VERSION; \
  Start-Process $service 'remove'-Wait; \
  # Allow users to connect from outside the docker container
  Set-Content -Path 'C:\rabbitmq.config' -Value '[{rabbit, [{loopback_users, []}]}].'; \
  \
	Write-Host 'Cleanup RabbitMQ installation ...'; \
	Remove-Item rabbit.exe -Force

# Register config file created above
ENV RABBITMQ_CONFIG_FILE "C:\rabbitmq"

# Redirect logs to terminal
ENV RABBITMQ_LOGS=- RABBITMQ_SASL_LOGS=-

EXPOSE 15691 15692 25672 4369 5671 5672 15671 15672

CMD $server = 'C:\Program Files\RabbitMQ Server\rabbitmq_server-{0}\sbin\rabbitmq-server.bat' -f $env:RABBITMQ_VERSION; \
  Start-Process $server 'install' -NoNewWindow -Wait