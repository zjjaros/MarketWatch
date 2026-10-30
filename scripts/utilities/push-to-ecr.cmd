@echo off
setlocal

set REGION=us-west-2
set ACCOUNT_ID=997956187142
set REPOSITORY=marketwatch
set REGISTRY=%ACCOUNT_ID%.dkr.ecr.%REGION%.amazonaws.com
set IMAGE=%REGISTRY%/%REPOSITORY%:latest

echo.
echo ========================================
echo  MarketWatch - Build and Push to ECR
echo ========================================
echo.

echo [1/3] Building Docker image...
docker build -t %IMAGE% .

if errorlevel 1 (
    echo.
    echo ERROR: Docker build failed.
    exit /b 1
)

echo.
echo [2/3] Logging into ECR...
aws ecr get-login-password --region %REGION% | docker login --username AWS --password-stdin %REGISTRY%

if errorlevel 1 (
    echo.
    echo ERROR: ECR login failed.
    exit /b 1
)

echo.
echo [3/3] Pushing image to ECR...
docker push %IMAGE%

if errorlevel 1 (
    echo.
    echo ERROR: Docker push failed.
    exit /b 1
)

echo.
echo ========================================
echo  SUCCESS!
echo ========================================
echo.
echo Image pushed:
echo %IMAGE%
echo.

endlocal