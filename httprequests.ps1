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
    $runspaces += [PSCustomObject]@{
        Runspace = $runspace
        Handle = $runspace.BeginInvoke()
    }
}

# Wait for all runspaces to complete
$runspaces | ForEach-Object {
    $_.Runspace.EndInvoke($_.Handle)
}

# Retrieve and output the results
$runspaces | ForEach-Object {
    $result = $_.Runspace.EndInvoke($_.Handle)
    Write-Output "Request: StatusCode = $($result.StatusCode), ResponseTime = $($result.ResponseTime) ms, ErrorMessage = $($result.ErrorMessage)"
    $_.Runspace.Dispose()
}

# Close the runspace pool
$runspacePool.Close()
$runspacePool.Dispose()
