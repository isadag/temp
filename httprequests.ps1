param (
    [Parameter(Mandatory=$true)]
    [string]$Url,

    [Parameter(Mandatory=$true)]
    [int]$Count
)

# Create an ArrayList to store job results
$results = New-Object System.Collections.ArrayList

# Start parallel jobs
for ($i = 1; $i -le $Count; $i++) {
    $job = Start-Job -ScriptBlock {
        param($Url)

        try {
            $response = Invoke-WebRequest -Uri $Url -Method Get -TimeoutSec 30 -ErrorAction Stop
            $statusCode = $response.StatusCode
            $responseTime = $response.Headers['X-Response-Time']
            $errorMessage = $null
        } catch {
            $statusCode = $_.Exception.Response.StatusCode.Value__
            $responseTime = 0
            $errorMessage = $_.Exception.Message
        }

        return @{
            StatusCode = $statusCode
            ResponseTime = $responseTime
            ErrorMessage = $errorMessage
        }
    } -ArgumentList $Url

    $results.Add($job) | Out-Null
}

# Wait for all jobs to complete
$results | ForEach-Object { $_ | Wait-Job }

# Retrieve and output the results
$results | ForEach-Object {
    $result = Receive-Job -Job $_
    Write-Output "Request: StatusCode = $($result.StatusCode), ResponseTime = $($result.ResponseTime) ms, ErrorMessage = $($result.ErrorMessage)"
    Remove-Job -Job $_
}
