
$ErrorActionPreference = "Stop"

$Region = "us-west-2"
$DbIdentifier = "marketwatch-db"
$RecoveryFile = Join-Path $PSScriptRoot "recovery.auto.tfvars"
$PendingFile = Join-Path $PSScriptRoot "recovery.pending.tfvars"

Set-Location $PSScriptRoot

if (Test-Path $PendingFile) {
    throw "A pending recovery file already exists. Resolve the previous teardown before starting another."
}

Write-Host "Checking RDS instance..."

$dbStatus = aws rds describe-db-instances `
    --db-instance-identifier $DbIdentifier `
    --region $Region `
    --query "DBInstances[0].DBInstanceStatus" `
    --output text

if ($LASTEXITCODE -ne 0) {
    throw "Could not find the RDS instance. No resources were destroyed."
}

if ($dbStatus -ne "available") {
    throw "RDS status is '$dbStatus', not 'available'. Wait until it is available."
}

$snapshotId = "marketwatch-db-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

Write-Host "This will snapshot '$DbIdentifier' and destroy Terraform-managed infrastructure."
Write-Host "Recovery snapshot: $snapshotId"
$confirmation = Read-Host "Type DESTROY to continue"

if ($confirmation -cne "DESTROY") {
    Write-Host "Cancelled. Nothing was destroyed."
    exit 0
}

Write-Host "Creating RDS snapshot..."
aws rds create-db-snapshot `
    --db-instance-identifier $DbIdentifier `
    --db-snapshot-identifier $snapshotId `
    --region $Region

if ($LASTEXITCODE -ne 0) {
    throw "Snapshot creation failed. Infrastructure has not been destroyed."
}

Write-Host "Waiting for snapshot to become available..."
aws rds wait db-snapshot-available `
    --db-snapshot-identifier $snapshotId `
    --region $Region

if ($LASTEXITCODE -ne 0) {
    throw "Snapshot wait failed. Infrastructure has not been destroyed."
}

# Save the recovery point separately so Terraform won't load it
# while the existing database still exists.
@"
db_snapshot_identifier = "$snapshotId"
skip_final_snapshot    = true
"@ | Set-Content -Path $PendingFile -Encoding ascii

Write-Host "Snapshot is available: $snapshotId"
Write-Host "Destroying Terraform-managed infrastructure..."

terraform destroy -auto-approve

if ($LASTEXITCODE -ne 0) {
    Write-Warning "Terraform destroy failed or was incomplete."
    Write-Warning "Recovery snapshot preserved: $snapshotId"
    Write-Warning "Pending recovery file preserved: $PendingFile"
    Write-Warning "Do not run up.ps1 until the partial teardown is resolved."
    exit 1
}

# Only promote the new recovery point after a successful destroy.
Move-Item -Path $PendingFile -Destination $RecoveryFile -Force

Write-Host ""
Write-Host "Teardown complete."
Write-Host "Recovery snapshot saved in $RecoveryFile"
Write-Host "Next time, run .\up.ps1 to restore the environment."