Param
(
    [Parameter(Mandatory = $False, ValueFromPipelineByPropertyName = $True)][Alias('OUTPUT')]  [string] $SaveDir = "$PSScriptRoot\iPlayer_Episodes\", #b006q2x0 p0ff9dvh
    [Parameter(Mandatory = $False, ValueFromPipelineByPropertyName = $True)][Alias('LOGDIR')]  [string] $SRCDIR = "$PSScriptRoot\iPlayer_Logs\",
    [Parameter(Mandatory = $False, ValueFromPipelineByPropertyName = $True)][Alias('PID')]     [string] $SrcPID = "b007r6vx", #b006q2x0 p0ff9dvh
    [Parameter(Mandatory = $False, ValueFromPipelineByPropertyName = $True)][Alias('MODE')]    [string] $FileMode = "BATCH" #BATCH/JOB
)

Add-Type -AssemblyName PresentationFramework
Clear-Host
if (-not(Test-Path -Path $SaveDir -PathType Container -IsValid)) {
    Write-Host "Invalid OUTPUT parameter ($SaveDir)"
    exit 1
}
if (-not(Test-Path -Path $SRCDIR -PathType Container -IsValid)) {
    Write-Host "Invalid LOGDIR parameter ($SRCDIR)"
    exit 2
}

$ErrorActionPreference = 'Inquire'
$NewLine = [Convert]::ToChar(10)
$ValidModes = @("batch", "job")

$BJobMode = $false

if ($FileMode) {
    $FileMode = $FileMode.ToString().ToLower()
    if ($FileMode -notin $ValidModes){
        Write-Host "Invalid FILEMODE parameter ($FileMode)"
        exit 3
    }
    else{
        $BJobMode = ($FileMode -eq $ValidModes[1])
    }
}


#where is the XAML file?
$xamlFile = "$PSScriptRoot\Window1.xaml"

#create window
$inputXML = Get-Content $xamlFile -Raw
$inputXML = $inputXML -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window'
[xml]$XAML = $inputXML

#Read XAML
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
try {
    $window = [Windows.Markup.XamlReader]::Load( $reader )
}
catch {
    Write-Warning $_.Exception
    throw
}

#Create variables based on form control names.
#Variable will be named as 'var_<control name>'

$xaml.SelectNodes("//*[@Name]") | ForEach-Object {
    #"trying item $($_.Name)";
    try {
        Set-Variable -Name "var_$($_.Name)" -Value $window.FindName($_.Name) -ErrorAction Stop
    } catch {
        throw
   }
}

Function TestFile()
{
    Param
    (
         [Parameter(Mandatory=$true, Position=0)] [string] $TargetDIR,
         [Parameter(Mandatory=$true, Position=1)] [string] $TargetPID
    )

    $Target = $TargetDIR+$TargetPID+".TXT"

    if (-not(Test-Path -Path $Target -PathType Leaf)) {
        Write-Host "The LOG file [$Target] does not exist - retrieving data...."
        try {
            $EpData = (get_iplayer --nocopyright --refresh -i --pid $TargetPID --pid-recursive)
            $EpData | out-file $Target
    
            Write-Host "The file [$Target] has been created."
        }
        catch {
            throw $_.Exception.Message
        }
    }
}
Function Refresh_Click()
{
    if ([System.Windows.MessageBox]::Show("Download New Listings?" + $NewLine + $NewLine + "(This may take some time)","Refresh Data from BBC",1,32) -eq "OK"){

        $Target = $var_txtPID.Text.ToString()

        if ($var_radioFull.isChecked){
            Write-Host "Getting complete episodes and metadata"
            $EpData = (get_iplayer --nocopyright --refresh -i --pid $Target --pid-recursive)
            $EpData | out-file $SRCDIR$Target".txt"
        }
        else {
            Write-Host "Getting episodes only"
            $EpData = (get_iplayer --nocopyright --refresh -i --pid $Target --pid-recursive-list)
            $EpData | out-file $SRCDIR$Target".txt"
        }

        $SrcEpisodes = (. "$PSScriptRoot\ParseGetIPlayerData.ps1" -DataFile ($SRCDIR+$Target+".TXT"))

        if ($null -ne $SrcEpisodes[0].Brand){
            $window.Title = $SrcEpisodes[0].Brand
        }
        else{
            $window.Title = "iPlayer Episodes"
        }
        
        Write-host "download complete"

        $var_DataGridRecordings.ItemsSource = @($SrcEpisodes)

    }
}


Function CheckCompletedJobs()
{
    Get-Job -State Completed | ForEach-Object { 
        Write-Host "Completed Job:    " $_.Name.Substring(4)
        $A=(Get-Job -Name $_.Name | Receive-Job)
        if ($A[7].Contains("No media streams found for requested programme versions and recording quality")) {
            Write-Host "NO STREAM AVAILABLE"
        }
        $_ | Remove-Job
    }

}
Function Perform_Click()
{
    if ($var_DataGridRecordings.SelectedItems.Count -eq 0){
        if ([System.Windows.MessageBox]::Show("Select ALL valid?" + $NewLine + $NewLine + "(This will refresh the list, but not download)","No Items Selected",4,32) -eq "Yes"){
            $var_DataGridRecordings.SelectAll()
            # Looks wonky - but all items are selected
            $var_DataGridRecordings.Refresh
        }
    }
    else {
        #(get_iplayer --nocopyright --force --overwrite    --subtitles --thumb --tracklist --pid b007r6vx --pid-recursive --subdir --subdir-format="<type>\<quality>\<series>" --tv-quality="fhd,hd" --radio-quality="high,std" -o "D:\Glastonbury"
        $BaseOptions = " --nocopyright"
        $ExtraOptions = ' --subdir --subdir-format=`"<type>\<quality>\<series>`"'

        if ($var_radioAll.IsChecked){
            $BaseOptions += ' --force --overwrite'
        }
        if ($var_chkSubTitle.IsChecked){
            $BaseOptions += ' --subtitles'
        }

        if ($var_chkThumbnail.IsChecked){
            $BaseOptions += ' --thumb'
        }

        if ($var_chkTrackList.IsChecked){
            $BaseOptions += ' --tracklist'
        }

        if ($var_radioTV.IsChecked){
            $ExtraOptions += ' --type="tv"'
        }
        if ($var_radioRadio.IsChecked){
            $ExtraOptions += ' --type="radio"'
        }

        $ExtraOptions += ' --tv-quality="'
        $ExtraOptions += ($var_ComboTVQuality.Items[$var_ComboTVQuality.SelectedIndex..$var_ComboTVQuality.Items.Count] | Join-String -Separator ',')
        $ExtraOptions += '"'

        $ExtraOptions += ' --radio-quality="'
        $ExtraOptions += ($var_ComboRadioQuality.Items[$var_ComboRadioQuality.SelectedIndex..$var_ComboRadioQuality.Items.Count] | Join-String -Separator ',')
        $ExtraOptions += '"'

        $ExtraOptions += ' -o '
        if ($var_txtSaveDir.Text.contains(" ") -eq $true) {
            $ExtraOptions += '"'
        }
        $ExtraOptions += $var_txtSaveDir.Text
        if ($var_txtSaveDir.Text.contains(" ") -eq $true) {
            $ExtraOptions += '"'
        }

        if ($BJobMode){
            $window.Hide()

            Write-Host "Processing Selected Recordings:"
        }
        else{
            $TargetFile = $var_txtSaveDir.Text+$var_txtPID.Text.trim()+".bat"
            New-item $TargetFile -force
        }
        

        $jobs = foreach ($Record in $var_DataGridRecordings.SelectedItems){

            $FileName = $Record.episodeshort

            $EpisodeOptions = " --PID "
            $EpisodeOptions += $Record.PID

            if ($BJobMode){
                $running = @(Get-Job | Where-Object { $_.State -eq 'Running' })
                if ($running.Count -ge 10) {
                    $running | Wait-Job -Any | Out-Null
                }

                if ($running.Count -ne 0) {
                    CheckCompletedJobs
                }

                Write-Host "Starting Job for: " $FileName
                $FullOpt = '& get_iplayer.cmd',$BaseOptions,$EpisodeOptions,$ExtraOptions -join ""

                Start-Job -Name "Get $FileName" -ArgumentList $FullOpt -ScriptBlock {
                  param($Command)
                    Invoke-Expression $Command
                }
            }
            else{
                Write-Host $FileName
                $FullOpt = "call get_iplayer",$BaseOptions,$EpisodeOptions,$ExtraOptions -join ""
                $FullOpt >> $TargetFile
            }

        }

        if ($BJobMode){
            $jobs | Wait-Job

            CheckCompletedJobs

            Write-Host "Ended Processing Selected Recordings"
            $Null = $window.ShowDialog()
        }
        else{
            Set-Clipboard -Value $TargetFile
            $null = ([System.Windows.MessageBox]::Show("$TargetFile Created" + $NewLine + $NewLine + "(Path has been copied to clipboard)","Batch Created",0,64) -eq "OK")
        }
    }
}

$var_txtPID.Text = $SrcPID
$var_txtSaveDir.Text = $SaveDir

$var_radioBoth.isChecked = $True
$var_ComboRadioQuality.Items.Add("high") | out-null
$var_ComboRadioQuality.Items.Add("std") | out-null
$var_ComboRadioQuality.Items.Add("med") | out-null
$var_ComboRadioQuality.Items.Add("low") | out-null
$var_ComboRadioQuality.SelectedItem = "high"

$var_ComboTVQuality.Items.Add("fhd") | out-null
$var_ComboTVQuality.Items.Add("hd") | out-null
$var_ComboTVQuality.Items.Add("sd") | out-null
$var_ComboTVQuality.Items.Add("web") | out-null
$var_ComboTVQuality.Items.Add("mobile") | out-null
$var_ComboTVQuality.SelectedItem = "fhd"

TestFile $SRCDIR $SrcPID

$SrcEpisodes = (. "$PSScriptRoot\ParseGetIPlayerData.ps1" -DataFile ($SRCDIR+$SrcPID+".TXT"))

$var_DataGridRecordings.ItemsSource = @($SrcEpisodes)

#Set window title to relevant Show Title if metadata is present
if ($null -ne $SrcEpisodes[0].Brand){
    $window.Title = $SrcEpisodes[0].Brand
}
else{
    $window.Title = "iPlayer Episodes"
}

#Bubble up event handler
[System.Windows.RoutedEventHandler]$Script:CheckedEventHandler = {
    switch ($_.source.name){
        "radioBoth"{
            $var_DataGridRecordings.SelectedItems.Clear
            $var_DataGridRecordings.ItemsSource = $SrcEpisodes
        }
        "radioTV"{
            $Temp = $SrcEpisodes | Where-Object -FilterScript { $_.type -eq "tv" }
            $var_DataGridRecordings.SelectedItems.Clear       
            $var_DataGridRecordings.ItemsSource = $Temp
        }
        "radioRadio"{
            $Temp = $SrcEpisodes | Where-Object -FilterScript { $_.type -eq "radio" }
            $var_DataGridRecordings.SelectedItems.Clear
            $var_DataGridRecordings.ItemsSource = $Temp
        }
        default {
            $_.source.name
        }
    }
}

$var_radioBoth.AddHandler([System.Windows.Controls.RadioButton]::CheckedEvent, $CheckedEventHandler)
$var_radioTV.AddHandler([System.Windows.Controls.RadioButton]::CheckedEvent, $CheckedEventHandler)
$var_radioRadio.AddHandler([System.Windows.Controls.RadioButton]::CheckedEvent, $CheckedEventHandler)

$var_btnRefresh.Add_Click({Refresh_Click})
$var_btnPerform.Add_Click({Perform_Click})

$window.Add_Loaded({
  $window.Activate()
})

$Null = $window.ShowDialog()

$var_radioRadio.RemoveHandler([System.Windows.Controls.RadioButton]::CheckedEvent, $CheckedEventHandler)
$var_radioTV.RemoveHandler([System.Windows.Controls.RadioButton]::CheckedEvent, $CheckedEventHandler)
$var_radioBoth.RemoveHandler([System.Windows.Controls.RadioButton]::CheckedEvent, $CheckedEventHandler)

$ErrorActionPreference = 'Continue'