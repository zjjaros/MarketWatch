
$ErrorActionPreference = "Stop"

$Region = "us-west-2"
$DbIdentifier = "marketwatch-db"
$RecoveryFile = Join-Path $PSScriptRoot "recovery.auto.tfvars"
$PendingFile = Join-Path $PSScriptRoot "recovery.pending.tfvars"

Set-Location $PSScriptRoot

# Query AWS for the database rather than relying on potentially stale
# Terraform state.
$foundDbIdentifier = aws rds describe-db-instances `
    --region $Region `
    --query "DBInstances[?DBInstanceIdentifier=='$DbIdentifier'].DBInstanceIdentifier | [0]" `
    --output text

if ($LASTEXITCODE -ne 0) {
    throw "Could not query RDS. Check AWS credentials and connectivity."
}

# If a previous teardown left a pending recovery file, only promote it
# once AWS confirms that the database no longer exists.
if (Test-Path $PendingFile) {
    if ($foundDbIdentifier -ne "None" -and $foundDbIdentifier) {
        throw "The database still exists and a pending recovery file is present. Resolve the incomplete teardown before running apply."
    }

    Write-Host "Database is absent. Recovering the pending snapshot configuration..."
    Move-Item -Path $PendingFile -Destination $RecoveryFile -Force
}

# Refuse to proceed without an explicit recovery configuration.
if (-not (Test-Path $RecoveryFile)) {
    throw "Missing recovery.auto.tfvars. Refusing to create a database without an explicit recovery snapshot."
}

Write-Host ""
Write-Host "Using recovery configuration:"
Get-Content $RecoveryFile

Write-Host ""
Write-Host "Planning infrastructure creation..."
terraform plan

if ($LASTEXITCODE -ne 0) {
    throw "Terraform plan failed."
}

Write-Host ""
$confirmation = Read-Host "Review the plan above. Type APPLY to create infrastructure and restore the database"

if ($confirmation -cne "APPLY") {
    Write-Host "Cancelled. No infrastructure was created."
    exit 0
}

terraform apply -auto-approve

if ($LASTEXITCODE -ne 0) {
    throw "Terraform apply failed. Review the error before retrying."
}

Write-Host ""
Write-Host "Infrastructure creation completed. Verify the database and application health."