@echo off

:: $Date$ 
:: $Revision$
:: $Author$

set curdir=%CD%
set running=bot.running
if not exist %running% (
  echo 1 > %running%
  call firebot_win_git.bat debug
  cd %curdir%
  erase %running%
) else (
  echo A bot is already running.
  echo Erase the file %running% if this is not the case
)