@{
    # PSScriptAnalyzer policy for the app-it-windows templates.
    #
    # Gate = Error + Warning. The windows-latest CI job lints every .ps1 here
    # with `Invoke-ScriptAnalyzer -Settings <this file>` and fails on any result.
    #
    # One rule is excluded, on purpose:
    #
    #   PSAvoidUsingWriteHost — these are user-facing launcher / build / inspect
    #     scripts whose whole job is to print status to the console a developer is
    #     watching. Write-Host is the correct tool for that: Write-Information is
    #     hidden unless $InformationPreference is changed, and Write-Output would
    #     pollute the pipeline / return values. This is the standard exclusion for
    #     CLI-style scripts; everything else in the default Error+Warning set
    #     (including BOM, singular-noun, ShouldProcess, and unused-variable rules)
    #     is enforced and kept clean.
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        'PSAvoidUsingWriteHost'
    )
}
