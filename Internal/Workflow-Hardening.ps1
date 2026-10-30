#requires -Version 5.1

Set-StrictMode -Version 2.0

function Get-LegionGoLauncherMutexName {
    return 'Global\LegionGo-AMD-Driver-Toolkit-Installer'
}

function Enter-LegionGoLauncherMutex {
    $Mutex = $null
    try {
        $Mutex = New-Object -TypeName System.Threading.Mutex -ArgumentList @($false,(Get-LegionGoLauncherMutexName))
        $Acquired = $false
        try {
            $Acquired = [bool]$Mutex.WaitOne(0)
        }
        catch [System.Threading.AbandonedMutexException] {
            # The prior process terminated without releasing the mutex. Windows
            # transfers ownership to this process, so recovery may proceed.
            $Acquired = $true
        }
        if (-not $Acquired) {
            $Mutex.Dispose()
            return $null
        }
        return $Mutex
    }
    catch {
        if ($null -ne $Mutex) { try { $Mutex.Dispose() } catch {} }
        throw
    }
}

function Exit-LegionGoLauncherMutex {
    param([System.Threading.Mutex]$Mutex)
    if ($null -eq $Mutex) { return }
    try { $Mutex.ReleaseMutex() } catch {}
    try { $Mutex.Dispose() } catch {}
}

function Test-LegionGoForeignResumeTaskName {
    param([Parameter(Mandatory=$true)][AllowEmptyString()][string]$TaskName)
    if ([string]::IsNullOrWhiteSpace($TaskName)) { return $false }
    if ($TaskName -notlike 'LegionGo-AMD-*-Resume') { return $false }
    return ($TaskName -ine [string]$Script:ResumeTaskName)
}

function Get-ForeignLegionGoResumeTasks {
    try {
        $Tasks = @(Get-ScheduledTask -ErrorAction Stop)
    }
    catch {
        throw ('Unable to enumerate scheduled tasks before installation. No workflow state was changed. {0}' -f $_.Exception.Message)
    }
    return @(
        $Tasks |
        Where-Object { Test-LegionGoForeignResumeTaskName -TaskName ([string]$_.TaskName) } |
        Sort-Object TaskPath,TaskName
    )
}

function Assert-NoForeignLegionGoResumeTask {
    $Conflicts = @(Get-ForeignLegionGoResumeTasks)
    if ($Conflicts.Count -eq 0) { return }

    $TaskDescriptions = @(
        $Conflicts | ForEach-Object {
            $TaskPath = [string]$_.TaskPath
            if ([string]::IsNullOrWhiteSpace($TaskPath)) { $TaskPath = '\' }
            ('{0}{1}' -f $TaskPath,[string]$_.TaskName)
        }
    )
    throw ('Another Legion Go AMD installer resume workflow is registered: {0}. Resolve or deliberately clean up that older workflow before running v5.0. No changes were made.' -f ($TaskDescriptions -join ', '))
}

function Get-LegionGoRollbackOutcomeStatus {
    param(
        [Parameter(Mandatory=$true)][ValidateSet('Failure','Interruption')][string]$Context,
        [Parameter(Mandatory=$true)][bool]$BaseRestoreOk,
        [Parameter(Mandatory=$true)][bool]$ExtensionRestoreOk
    )

    $RollbackProofPassed = ($BaseRestoreOk -and $ExtensionRestoreOk)
    if ($Context -eq 'Failure') {
        $TransactionStatus = if ($RollbackProofPassed) { 'RecoveredAfterFailure' } else { 'RecoveryFailedAfterFailure' }
    }
    else {
        $TransactionStatus = if ($RollbackProofPassed) { 'RecoveredAfterInterruption' } else { 'RecoveryFailedAfterInterruption' }
    }

    return [pscustomobject]@{
        Context = $Context
        RollbackProofPassed = [bool]$RollbackProofPassed
        TransactionStatus = $TransactionStatus
    }
}

function Get-LegionGoFailureCheckpointDecision {
    param(
        [Parameter(Mandatory=$true)][AllowEmptyString()][string]$Stage,
        [Parameter(Mandatory=$true)][AllowEmptyString()][string]$TransactionStatus
    )

    $NextStage = $Stage
    $Disposition = 'PreserveCheckpoint'

    if ($Stage -eq 'AwaitingTestSigningReboot') {
        $NextStage = 'SignedPackageReady'
        $Disposition = 'RearmTestSigning'
    }
    elseif ($Stage -eq 'ReadyForInstall') {
        if ($TransactionStatus -in @('DriverTransactionInProgress','RecoveryAttemptedAfterInterruption','RecoveryFailedAfterInterruption','RecoveryFailedAfterFailure')) {
            $Disposition = 'RecoverInterruptedTransaction'
        }
        elseif ($TransactionStatus -eq 'DriverInstalledPreReboot') {
            $Disposition = 'ResumeInstalledCheckpoint'
        }
        else {
            $NextStage = 'SignedPackageReady'
            $Disposition = 'RearmTestSigning'
        }
    }

    return [pscustomobject]@{
        OriginalStage = $Stage
        Stage = $NextStage
        TransactionStatus = $TransactionStatus
        Disposition = $Disposition
    }
}

function Complete-LegionGoRecoveryRearm {
    param($State, [datetime]$PreviousBoot, [datetime]$CurrentBoot, [bool]$TestSigningConfigured)
    $Status = ''
    if ($null -ne $State.PSObject.Properties['TransactionStatus']) { $Status = [string]$State.TransactionStatus }
    if ($Status -notin @('RecoveredAfterFailure','RecoveredAfterInterruption')) { return }
    if ([string]$State.Stage -ne 'AwaitingTestSigningReboot' -or $CurrentBoot -le $PreviousBoot -or -not $TestSigningConfigured) {
        throw 'Recovery re-arm requires a verified new Test Signing boot.'
    }
    $Proof = $State.PSObject.Properties['RecoveryRollbackProofPassed']
    if ($null -eq $Proof -or $Proof.Value -isnot [bool] -or $Proof.Value -ne $true) {
        throw 'Recovery re-arm requires successful rollback proof.'
    }
    # Retain the recovery evidence, but consume the old transaction marker only
    # after Stage 1 has verified the newly authorized reboot boundary.
    Set-StateProperty $State 'PreviousRecoveryTransactionStatus' $Status
    Set-StateProperty $State 'RecoveryRearmedAt' (Get-Date).ToString('o')
    Set-StateProperty $State 'TransactionStatus' 'ReadyAfterRecoveryRearm'
}

function Get-LegionGoStage2EntryDecision {
    param(
        [Parameter(Mandatory=$true)][AllowEmptyString()][string]$Stage,
        [Parameter(Mandatory=$true)][AllowEmptyString()][string]$TransactionStatus,
        [Parameter(Mandatory=$true)][bool]$TestSigningConfigured
    )

    if ($Stage -ne 'ReadyForInstall') { return 'InvalidStage' }
    if ($TransactionStatus -in @('RecoveredAfterFailure','RecoveredAfterInterruption')) { return 'RearmTestSigning' }
    if ($TransactionStatus -in @('DriverTransactionInProgress','RecoveryAttemptedAfterInterruption','RecoveryFailedAfterInterruption','RecoveryFailedAfterFailure')) { return 'RecoverInterruptedTransaction' }
    if ($TransactionStatus -eq 'DriverInstalledPreReboot') { return 'ResumeInstalledCheckpoint' }
    if (-not $TestSigningConfigured) { return 'RequiresTestSigning' }
    return 'Proceed'
}
