[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Arguments,

    [Parameter(ValueFromPipeline = $true)]
    [AllowNull()]
    [object]$PipelineInput
)

begin {
    $ErrorActionPreference = 'Stop'
    $cliPath = Join-Path $PSScriptRoot 'cdp-cli.mjs'
    $pipelineValues = [System.Collections.Generic.List[string]]::new()
}

process {
    if ($null -ne $PipelineInput) {
        $pipelineValues.Add([string]$PipelineInput)
    }
}

end {
    $nodeCommand = Get-Command node -ErrorAction SilentlyContinue
    if (-not $nodeCommand) {
        throw 'Node.js 22 or newer is required. Install Node.js and ensure node.exe is on PATH.'
    }

    $nodeVersion = & $nodeCommand.Source --version
    if ($LASTEXITCODE -ne 0 -or $nodeVersion -notmatch '^v(?<Major>\d+)') {
        throw 'Unable to determine the installed Node.js version.'
    }
    if ([int]$Matches.Major -lt 22) {
        throw "Node.js 22 or newer is required. Found $nodeVersion."
    }

    if ($pipelineValues.Count -gt 0) {
        [string]$inputText = [string]::Join([Environment]::NewLine, $pipelineValues)
        $inputText | & $nodeCommand.Source $cliPath @Arguments
    } else {
        & $nodeCommand.Source $cliPath @Arguments
    }
    exit $LASTEXITCODE
}
