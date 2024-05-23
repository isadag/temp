# For powershell 5.1
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

        # Function to perform an HTTP request and return the response time, status code, and error message
        function Test-HttpRequest {
            param (
                [string]$Url
            )

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
        }

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
