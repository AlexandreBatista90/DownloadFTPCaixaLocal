@echo off
title Gerador de Backup Delphi
echo Iniciando backup do projeto...

:: ==========================================
:: 1. DESCOBRE ONDE ESTA SENDO EXECUTADO
:: ==========================================
set "PastaOrigem=%~dp0"
if "%PastaOrigem:~-1%"=="\" set "PastaOrigem=%PastaOrigem:~0,-1%"
for %%I in ("%PastaOrigem%") do set "NomeDoProjeto=%%~nxI"

:: ==========================================
:: 2. PASTA DESTINO
:: ==========================================
set "PastaDropbox=C:\Users\Alexandre\Dropbox\PROGRAMACAO\BackupBrutoProjetos"
:: ==========================================

:: Pega a data e hora do Windows
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set datetime=%%I
set "Ano=%datetime:~0,4%"
set "Mes=%datetime:~4,2%"
set "Dia=%datetime:~6,2%"
set "Hora=%datetime:~8,2%"
set "Min=%datetime:~10,2%"
set "DataHora=%Ano%-%Mes%-%Dia%_%Hora%h%Min%"

:: Cria nomes e pastas
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

if not exist "%PastaDropbox%" mkdir "%PastaDropbox%"

echo.
echo Criando regras de exclusao rigorosas...
:: Cria a lista negra direto na pasta temporaria do Windows para nao sujar seu projeto
set "ArquivoExclusao=%TEMP%\exc_delphi.txt"

:: 1. Ignora pastas de compilacao e historico
echo \__recovery\> "%ArquivoExclusao%"
echo \__history\>> "%ArquivoExclusao%"
echo \Win32\>> "%ArquivoExclusao%"
echo \Win64\>> "%ArquivoExclusao%"

:: 2. Ignora arquivos de lixo e cache que o Delphi gera sozinho
echo .dcu>> "%ArquivoExclusao%"
echo .local>> "%ArquivoExclusao%"
echo .identcache>> "%ArquivoExclusao%"
echo .stat>> "%ArquivoExclusao%"
echo .dres>> "%ArquivoExclusao%"
echo .~>> "%ArquivoExclusao%"

echo.
echo Copiando toda a estrutura e subpastas (ignorando lixo e pastas ocultas)...
:: O * pega todos os arquivos e pastas. 
:: /S e /E garantem que toda a arvore de pastas seja copiada.
:: /EXCLUDE barra o que definimos acima. E o xcopy ja ignora pastas ocultas nativamente.
xcopy "%PastaOrigem%\*" "%PastaTemp%\" /S /E /Y /Q /EXCLUDE:%ArquivoExclusao%

:: Limpa o arquivo de regras
del "%ArquivoExclusao%"

echo.
echo Compactando os arquivos direto para o Dropbox...
powershell.exe -nologo -noprofile -command "Compress-Archive -Path '%PastaTemp%\*' -DestinationPath '%PastaDropbox%\%NomeZip%' -Force"

echo.
echo Limpando rastros do computador...
rd /s /q "%PastaTemp%"

echo.
echo Realizando limpeza de backups antigos...
:: Encontra os arquivos do projeto atual, ordena do mais novo pro mais velho, pula os 5 primeiros e joga o resto na lixeira
for /f "skip=5 delims=" %%F in ('dir /b /o-d "%PastaDropbox%\%NomeDoProjeto%_*.zip" 2^>nul') do (
    echo - Movendo para a lixeira: %%F
    powershell.exe -nologo -noprofile -command "Add-Type -AssemblyName Microsoft.VisualBasic; [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile('%PastaDropbox%\%%F', 'OnlyErrorDialogs', 'SendToRecycleBin')"
)

echo.
echo ===================================================
echo SUCESSO! Backup concluido.
echo Arquivo gerado: %NomeZip%
echo Mantidos apenas os 5 backups mais recentes.
echo ===================================================
echo.
pause