# SQL Server 2022 Windows container dockerfile for Windows Server 2022
## Warning: Restarting windows container causes the machine key to change and hence if you have any encryption configured then restarting SQL On Windows containers
## breaks the encryption key chain in SQL Server. 

FROM mcr.microsoft.com/windows/servercore:ltsc2022

ENV sa_password="_" \
    attach_dbs="[]" \
    ACCEPT_EULA="_" \
    sa_password_path="C:\ProgramData\Docker\secrets\sa-password"

COPY start.ps1 /

RUN MKDIR temp
WORKDIR C:/temp

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

RUN Invoke-WebRequest -Uri https://go.microsoft.com/fwlink/p/?linkid=2215158 -OutFile SQL2022-SSEI-Dev.exe
RUN Start-Process -Wait -FilePath C:\temp\SQL2022-SSEI-Dev.exe -ArgumentList /ACTION=Download, /MEDIATYPE=CAB, /MEDIAPATH=C:/temp, /QUIET, /VERBOSE

RUN Start-Process -Wait -FilePath C:\temp\SQLServer2022-DEV-x64-ENU.exe -ArgumentList /qs, /x:setup ; \
    .\setup\setup.exe /q /ACTION=Install /INSTANCENAME=MSSQLSERVER /FEATURES=SQLEngine /UPDATEENABLED=0 /SQLSVCACCOUNT='NT AUTHORITY\NETWORK SERVICE' /SQLSYSADMINACCOUNTS='BUILTIN\ADMINISTRATORS' /TCPENABLED=1 /NPENABLED=0 /IACCEPTSQLSERVERLICENSETERMS ;

RUN stop-service MSSQLSERVER ; \
    set-itemproperty -path 'HKLM:\software\microsoft\microsoft sql server\mssql16.MSSQLSERVER\mssqlserver\supersocketnetlib\tcp\ipall' -name tcpdynamicports -value '' ; \
    set-itemproperty -path 'HKLM:\software\microsoft\microsoft sql server\mssql16.MSSQLSERVER\mssqlserver\supersocketnetlib\tcp\ipall' -name tcpport -value 1433 ; \
    set-itemproperty -path 'HKLM:\software\microsoft\microsoft sql server\mssql16.MSSQLSERVER\mssqlserver\' -name LoginMode -value 2 ;

WORKDIR C:/

RUN Remove-Item .\temp -Force -Recurse

HEALTHCHECK CMD [ "sqlcmd", "-Q", "select 1" ]

CMD .\start -sa_password $env:sa_password -ACCEPT_EULA $env:ACCEPT_EULA -attach_dbs \"$env:attach_dbs\" -Verbose