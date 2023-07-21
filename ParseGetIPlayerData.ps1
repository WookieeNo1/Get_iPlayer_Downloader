Param
(
    [Parameter(Mandatory = $False, ValueFromPipelineByPropertyName = $True)][Alias('DataFile')] [string] $Data = "$PSScriptRoot\iPlayer_Logs\b007r6vx.txt"
)
Clear-Host

Function Compare-ObjectProperties {
    Param(
        [PSObject]$ReferenceObject,
        [PSObject]$DifferenceObject
    )
    $objprops = $ReferenceObject | Get-Member -MemberType Property,NoteProperty | % Name
    $Refprops = $objprops
    $Diffprops = $DifferenceObject | Get-Member -MemberType Property,NoteProperty | % Name
    $objprops += $Diffprops
    $objprops = $objprops | Sort-Object | Select-Object -Unique

    $diffs = @()
    foreach ($objprop in $objprops) {
        if (($Refprops -notcontains $objprop)) {
            $diffs += $objprop
        }
    }
    if ($diffs) {return ($diffs )}
}

$SrcData = Get-Content -Path $Data

$bEpisodesOnly = ($SrcData[-1].StartsWith("INFO:"))

$bSrcFiles = $false
$bSrcFileDetails = $false
$bSkipBlankLine = $false
$bSkipFirstLine = $false
$bMultipleDefinitions = $false 

$SrcObjCollection = @()

$Multiples = New-Object System.Collections.Generic.List[string]

$SrcObj = New-Object PSObject

foreach ($Line in $SrcData){
    $Line = $Line.Replace('&#x2013;', "-")
    $Line = $Line.Replace('&#x2019;', "'")
    $Line = $Line.Replace('&#x2026;', "...")

    if ($bSrcFiles){
        $bSrcFiles = ($Line -ne "")

        if ($Line.StartsWith("INFO:")){
            $bSrcFiles = $false
        }
        if ($bSrcFiles -eq $true) {
            if ($bEpisodesOnly) {
                # NO METADATA!
                #Glastonbury 2023: Classic Performances - Blur at Glastonbury 2009, , m001nhjm
                #Glastonbury 2023 - We Love Glastonbury, , m001n49m
                if ($Line.contains(":") -eq $True) {
                    $Title = $Line.Split(":")[1].Split(",")[0].Trim()
                }
                else {
                    $Title = $Line.Split(",")[0].Trim()
                }
                $gPID = $Line.Split(",")[-1].Trim()

                $SrcObj = New-Object PSObject

                $SrcObj | Add-Member -MemberType NoteProperty -Name "episodeshort" -Value $Title
                $SrcObj | Add-Member -MemberType NoteProperty -Name "pid" -Value $gPID
                $SrcObj | Add-Member -MemberType NoteProperty -Name "type" -Value "---"
                $SrcObj | Add-Member -MemberType NoteProperty -Name "runtime" -Value "---"
                $SrcObj | Add-Member -MemberType NoteProperty -Name "expires" -Value "---"

                $SrcObjCollection += $SrcObj

            }
        }
    }
    elseif ($bSrcFileDetails -eq $false -and $Line -ne "" ){
        if ($Line.Equals("Episodes:")) {
            $bSrcFiles = $true
        }
        elseif ($Line.StartsWith("INFO: Processing")) {
            $bSrcFileDetails = $true
            $bSkipBlankLine = $true
            $bSkipFirstLine = $true
            $bMultipleDefinitions = $false 
            # Hack for spurious multiline entries in metadata 
            # really needs to detect "web:" metadata entry and process 2 following blank lines as metadata terminator
            $TerminalBlankLines=2

            $Multiples.Clear()

            $SrcObj = New-Object PSObject

        }
    }
    if ($bSrcFileDetails) {
        #1st Line -  INFO: Processing tv: 'Glastonbury: 1997 - Radiohead (p08gjnzz)'
        if ($Line -eq ""){
            if ($bSkipBlankLine -eq $true) {
                $bSkipBlankLine = $false
            }
            else {
                $TerminalBlankLines -= 1
                # Hack for spurious multiline entries in metadata 
                # really needs to detect "web:" metadata entry and process 2 following blank lines as metadata terminator
                if ($TerminalBlankLines -eq 0){
                    # Last Line of Object Reached
                    if ($bMultipleDefinitions){
                        $bMultipleDefinitions = $false

                        $SrcObj | Add-Member -MemberType NoteProperty -Name "Multiples" -Value "True"
                        $SrcObj | Add-Member -MemberType NoteProperty -Name "MultipleValues" -Value ($Multiples -join ";")
                    }
                    $bSrcFileDetails = $false
                    $SrcObjCollection += $SrcObj

                    # Ensure all entries have any new metadata fields
                    $ExtraProps = Compare-ObjectProperties $SrcObjCollection[0] $SrcObj
                    if ($null -ne $ExtraProps)
                    {
                        For ($num = 0 ; $num -le ($SrcObjCollection.Count - 2)  ; $num++) {
                            ForEach ( $NewProperty in $ExtraProps )
                            {
                                $SrcObjCollection[$num] | Add-Member -MemberType NoteProperty -Name $NewProperty -Value $SrcObj.episodeshort
                            }
                        }
                    }
                }
            } 
        }
        if ($bSrcFileDetails) {
            if ($Line -ne "") {
                # hack Reset terminator count
                if ($TerminalBlankLines -ne 2){
                    $TerminalBlankLines = 2
                }
                if ( $bSkipFirstLine ){
                    $bSkipFirstLine = $false
                }
                else {
                    #Details Lines
                    #brand:           Glastonbury
                    if ($Line.contains(":") -eq $false) {
                        # Fix for split lines - spurious newlines in metadata
                        $ExistingValue = $SrcObj.$DetailKey
                        $SrcObj | Add-Member -MemberType NoteProperty -Name $DetailKey -Value ($ExistingValue + " " + $Line) -Force
                    }
                    else
                    {
                        $DetailKey=$Line.Split(":",2)[0].Trim()
                        $DetailValue=$Line.Split(":",2)[1].Trim()
                        if ($DetailKey -eq "expires"){
                            #expires:         in 4 days 14 hours (2023-07-24T18:00:00+00:00)
                            $Parts=$DetailValue.Split("(")
                            $DetailValue = $Parts[1].TrimEnd(")")
                        }
                        if ($DetailKey -eq "runtime"){
                            #runtime:         60
                            $DetailValue = $DetailValue.PadLeft(3,"0").PadLeft(8," ")
                        }

                        $ExistingValue = $SrcObj.$DetailKey
    
                        if ($null -eq $ExistingValue) {
                            $SrcObj | Add-Member -MemberType NoteProperty -Name $DetailKey -Value $DetailValue
                        }
                        else
                        {
                            $bMultipleDefinitions = $true
                            $Multiples.Add($DetailKey)
                            $SrcObj | Add-Member -MemberType NoteProperty -Name $DetailKey -Value ($ExistingValue + ";" + $DetailValue) -Force
                        }
                    }
                }
            }
        }
    }
}
# Ensure last entry has all required metadata fields
$ExtraProps = Compare-ObjectProperties $SrcObjCollection[-1] $SrcObjCollection[0]
if ($null -ne $ExtraProps)
{
    ForEach ( $NewProperty in $ExtraProps ) {
        $SrcObjCollection[-1] | Add-Member -MemberType NoteProperty -Name $NewProperty -Value $SrcObjCollection[0].episodeshort
    }
}

$SrcObjCollection
