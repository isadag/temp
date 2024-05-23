param (
    [Parameter(Mandatory=$true)]
    [string]$Url,

    [Parameter(Mandatory=$true)]
    [int]$Count
)

# Define the script block to be run in each runspace
$scriptBlock = {
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
}

# Create runspace pool
$runspacePool = [runspacefactory]::CreateRunspacePool(1, $Count)
$runspacePool.Open()

# Create array to store the results
$results = @()

# Create and open runspaces
$runspaces = @()
for ($i = 1; $i -le $Count; $i++) {
    $runspace = [powershell]::Create().AddScript($scriptBlock).AddArgument($Url)
    $runspace.RunspacePool = $runspacePool
    $handle = $runspace.BeginInvoke()

    $runspaces += [PSCustomObject]@{
        Runspace = $runspace
        Handle = $handle
        Result = $null
    }
}

# Wait for all runspaces to complete
$runspaces | ForEach-Object {
    $_.Runspace.EndInvoke($_.Handle)
}

# Retrieve and store the results
$runspaces | ForEach-Object {
    $_.Result = $_.Runspace.EndInvoke($_.Handle)
    $_.Runspace.Dispose()
}

# Close the runspace pool
$runspacePool.Close()
$runspacePool.Dispose()

# Output the results
$results = $runspaces | ForEach-Object {
    $_.Result
}
$results | ForEach-Object {
    Write-Output "Request: StatusCode = $($_.StatusCode), ResponseTime = $($_.ResponseTime) ms, ErrorMessage = $($_.ErrorMessage)"
}
