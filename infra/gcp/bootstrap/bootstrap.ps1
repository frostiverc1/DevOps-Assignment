$BillingAccountId = "0146A6-2278BE-5DCED6"
$Suffix = "frosti"
$Region = "asia-south1"
$Environments = @("dev", "staging", "prod")

foreach ($Env in $Environments) {
    $ProjectId = "devops-assignment-$Env-$Suffix"
    $BucketName = "devops-tf-state-$Env-$Suffix"

    Write-Host "`n===================================================" -ForegroundColor Cyan
    Write-Host " Setting up GCP environment: $Env" -ForegroundColor Cyan
    Write-Host " Project ID : $ProjectId" -ForegroundColor Cyan
    Write-Host " State Bucket: $BucketName" -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor Cyan

    Write-Host "Creating project..."
    # Attempt to create. We use 2>&1 to capture stderr and prevent PowerShell from turning red.
    $createResult = gcloud projects create $ProjectId --name="DevOps Assignment $Env" --labels="environment=$Env,project=devops-assignment,managed-by=terraform" 2>&1

    Write-Host "Linking billing..."
    $billingResult = gcloud beta billing projects link $ProjectId --billing-account=$BillingAccountId 2>&1

    Write-Host "Enabling APIs (this takes a minute)..."
    $apiResult = gcloud services enable run.googleapis.com artifactregistry.googleapis.com compute.googleapis.com secretmanager.googleapis.com iam.googleapis.com cloudresourcemanager.googleapis.com iamcredentials.googleapis.com --project=$ProjectId 2>&1

    Write-Host "Creating state bucket..."
    $bucketResult = gcloud storage buckets create "gs://$BucketName" --project=$ProjectId --location=$Region --uniform-bucket-level-access 2>&1

    Write-Host "Enabling bucket versioning..."
    $versionResult = gcloud storage buckets update "gs://$BucketName" --versioning 2>&1
}

Write-Host "`n===================================================" -ForegroundColor Green
Write-Host " GCP Bootstrap Complete! " -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Green
