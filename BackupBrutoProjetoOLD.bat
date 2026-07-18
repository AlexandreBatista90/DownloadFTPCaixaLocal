@echo off
title Gerador de Backup Delphi
echo Iniciando backup do projeto...

:: ==========================================
:: 1. DESCOBRE ONDE ESTA SENDO EXECUTADO
:: ==========================================
:: Pega o caminho exato da pasta onde este .bat foi colado
set "PastaOrigem=%~dp0"
:: Remove a ultima barra invertida para evitar erros de leitura
if "%PastaOrigem:~-1%"=="\" set "PastaOrigem=%PastaOrigem:~0,-1%"

:: Extrai automaticamente apenas o nome da pasta atual
for %%I in ("%PastaOrigem%") do set "NomeDoProjeto=%%~nxI"

:: ==========================================
:: 2. CONFIGURE APENAS O DESTINO AQUI
:: ==========================================
set "PastaDropbox=C:\Users\Alexandre\Dropbox\PROGRAMACAO\BackupBrutoProjetos"
:: ==========================================

:: Pega a data e hora do Windows de forma segura para dar nome ao ZIP
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set datetime=%%I
set "Ano=%datetime:~0,4%"
set "Mes=%datetime:~4,2%"
set "Dia=%datetime:~6,2%"
set "Hora=%datetime:~8,2%"
set "Min=%datetime:~10,2%"
set "DataHora=%Ano%-%Mes%-%Dia%_%Hora%h%Min%"

:: Cria o nome do arquivo final
set "NomeZip=%NomeDoProjeto%_%DataHora%.zip"
set "PastaTemp=%TEMP%\BackupDelphi_%NomeDoProjeto%"

echo.
echo ===================================================
echo PROJETO IDENTIFICADO: %NomeDoProjeto%
echo LENDO DA PASTA: %PastaOrigem%
echo ===================================================
echo.

echo Limpando pasta temporaria...
if exist "%PastaTemp%" rd /s /q "%PastaTemp%"
mkdir "%PastaTemp%"

:: Cria a pasta no Dropbox caso ainda nao exista
if not exist "%PastaDropbox%" mkdir "%PastaDropbox%"

echo.
echo Copiando apenas arquivos essenciais (ignorando o lixo)...
:: Copia código-fonte e design
xcopy "%PastaOrigem%\*.dpr" "%PastaTemp%\" /Y /Q
xcopy "%PastaOrigem%\*.dproj" "%PastaTemp%\" /Y /Q
xcopy "%PastaOrigem%\*.pas" "%PastaTemp%\" /Y /Q
xcopy "%PastaOrigem%\*.dfm" "%PastaTemp%\" /Y /Q
:: Copia recursos e ícones
xcopy "%PastaOrigem%\*.res" "%PastaTemp%\" /Y /Q
xcopy "%PastaOrigem%\*.rc" "%PastaTemp%\" /Y /Q
xcopy "%PastaOrigem%\*.ico" "%PastaTemp%\" /Y /Q
xcopy "%PastaOrigem%\*.png" "%PastaTemp%\" /Y /Q
xcopy "%PastaOrigem%\*.jpg" "%PastaTemp%\" /Y /Q
:: Copia base de dados (se houver na pasta do projeto)
xcopy "%PastaOrigem%\*.dbf" "%PastaTemp%\" /Y /Q
xcopy "%PastaOrigem%\*.cdx" "%PastaTemp%\" /Y /Q
xcopy "%PastaOrigem%\*.dll" "%PastaTemp%\" /Y /Q

echo.
echo Compactando os arquivos direto para o Dropbox...
:: Usa o PowerShell embutido no Windows para zipar a pasta
powershell.exe -nologo -noprofile -command "Compress-Archive -Path '%PastaTemp%\*' -DestinationPath '%PastaDropbox%\%NomeZip%' -Force"

echo.
echo Limpando rastros do computador...
rd /s /q "%PastaTemp%"

echo.
echo ===================================================
echo SUCESSO! Backup concluido.
echo Arquivo gerado: %NomeZip%
echo Local salvo: %PastaDropbox%
echo ===================================================
echo.
pause