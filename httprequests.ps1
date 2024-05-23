param (
    [Parameter(Mandatory=$true)]
    [string]$Url,

    [Parameter(Mandatory=$true)]
    [int]$Count
)

# Start parallel jobs
for ($i = 1; $i -le $Count; $i++) {
    $results += Start-Job -ScriptBlock {
        param($Url)

        # Dot-source the script to make sure the function is available
        . $PSScriptRoot\ParallelHttpRequests.ps1

        # Call the function within the job
        Test-HttpRequest -Url $Url
    } -ArgumentList $Url
}

# Wait for all jobs to complete
$results | ForEach-Object { $_ | Wait-Job }

# Retrieve and output the results
$results | ForEach-Object {
    $result = Receive-Job -Job $_
    Write-Output "Request: StatusCode = $($result.StatusCode), ResponseTime = $($result.ResponseTime) ms, ErrorMessage = $($result.ErrorMessage)"
    Remove-Job -Job $_
}
