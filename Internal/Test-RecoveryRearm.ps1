#requires -Version 5.1
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
$Before=[datetime]'2026-10-28T10:00:00'
$After=$Before.AddMinutes(5)
foreach($Status in @('RecoveredAfterFailure','RecoveredAfterInterruption')) {
    foreach($Case in @('Valid','SameBoot','SigningOff','MissingProof','FalseProof','WrongStage')) {
        $State=[pscustomobject]@{Stage='AwaitingTestSigningReboot';TransactionStatus=$Status;RecoveryRollbackProofPassed=$true}
        $Boot=$After; $Signing=$true
        switch($Case) {
            'SameBoot' {$Boot=$Before}
            'SigningOff' {$Signing=$false}
            'MissingProof' {$State.PSObject.Properties.Remove('RecoveryRollbackProofPassed')}
            'FalseProof' {$State.RecoveryRollbackProofPassed=$false}
            'WrongStage' {$State.Stage='ReadyForInstall'}
        }
        $Blocked=$false
        try { Complete-LegionGoRecoveryRearm -State $State -PreviousBoot $Before -CurrentBoot $Boot -TestSigningConfigured:$Signing } catch { $Blocked=$true }
        if($Case -eq 'Valid') {
            if($Blocked -or $State.TransactionStatus -ne 'ReadyAfterRecoveryRearm' -or $State.PreviousRecoveryTransactionStatus -ne $Status) {throw "Valid recovery failed: $Status"}
            $State.Stage='ReadyForInstall'
            if((Get-LegionGoStage2EntryDecision -Stage $State.Stage -TransactionStatus $State.TransactionStatus -TestSigningConfigured:$true) -ne 'Proceed') {throw 'Rearmed recovery still loops.'}
        } elseif(-not $Blocked -or $State.TransactionStatus -ne $Status) {throw "Unsafe recovery accepted: $Case"}
    }
}
foreach($Status in @('DriverTransactionInProgress','RecoveryFailedAfterFailure','RecoveryFailedAfterInterruption')) {
    $State=[pscustomobject]@{Stage='AwaitingTestSigningReboot';TransactionStatus=$Status}
    Complete-LegionGoRecoveryRearm -State $State -PreviousBoot $Before -CurrentBoot $After -TestSigningConfigured:$true
    if((Get-LegionGoStage2EntryDecision -Stage 'ReadyForInstall' -TransactionStatus $State.TransactionStatus -TestSigningConfigured:$true) -ne 'RecoverInterruptedTransaction') {throw 'Unsafe transaction lost recovery guard.'}
}
Write-Output '[PASS] Recovery re-arm: both successful recovery types proceed only after proven rollback and a new Test Signing boot; unsafe and interrupted states remain blocked.'
