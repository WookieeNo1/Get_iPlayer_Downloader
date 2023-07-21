# Get_iPlayer_Downloader

Powershell GUI to simplify processing of Series and Episodes from BBC iPlayer using get_iplayer

https://github.com/get-iplayer/get_iplayer_win32/releases

This is a first cut - rapidly put up to allow downloads from the Glastonbury Set lists, which are rapidly vanishing. 

It is written using Powershell and requires the Windows Presentation Framework, so I don't know if non-windows users can use it. (Wine?)

There are issues with the interface, the final version will (hopefully) integrate the downloads - this version generates a batch file that can be run separately to download any selected files. 

***Retrieving Full metadata is quite slow*** - my system took just over 13 1/2 minutes to download the available Glastonbury listing, compared to just over 2 1/2 for the episode data only.
There is NO visual confirmation (yet) while it is running - just be patient...

It is better to get the Full data, as durations and expiry information is not available when only the episode data is retrieved. I have included the current (as of midnight 20th July) full metadata for Glastonbury 2023

So, here goes...

Grab all the files/directories from this repository and place them in a directory of your choosing.

Open up a Powershell window - I _really_ prefer Windows Terminal, but the standard PS Window works...

https://github.com/microsoft/terminal/releases

To run, cd to the directory and enter:

    .\Get_iPlayer_Downloader.ps1

This can accept 3 (optional) named parameters:

    OUTPUT  -  default value = $PSScriptRoot\iPlayer_Episodes\
    
               This is the target directory into which all recordings will be placed
               If used, checks for valid locations will exit if a non-valid value is present

    LOGDIR  -  default value = $PSScriptRoot\iPlayer_Logs\
    
               This is the directory which holds the downloaded series/episode and optional metadata retrieved from the BBC, named "<PID>.txt"
               If used, checking for valid locations will exit if a non-valid value is present

    PID     -  default value = b007r6vx - the master PID for all Glastonbury 2023 content
    
               Any PID from the BBC iPlayer site can be used. If no corresponding file can be found in the LOGDIR location, 
               an attempt will be made on startup to retrieve the full episode and metadata from iPlayer.

Finally, the main display will appear, as below:
![image](https://github.com/WookieeNo1/Get_iPlayer_Downloader/assets/83819273/3d3de610-4da3-4663-ad08-8718adea2d7d)

Firstly, if the full metadata is retrieved, the Window Title will show the "Brand" from the metadata, otherwise "iPlayer Episodes" will be present.

All selectable options have a tooltip, proving basic information as to the function of the option.

Proceding through the various elements of the window:

![image](https://github.com/WookieeNo1/Get_iPlayer_Downloader/assets/83819273/ef730b85-fc3b-480f-b578-10e4ca572367)

This section refers to the PID provided. The text box can be changed, but the GET button is currently disabled. My intention is to have this become enabled when the corresponding file is located in the LOGDIR, but this is not yet active. It may even be removed completely, and replaced with detecting code embedded in the text box's handler.

Instead, when the file exists, use the PID parameter when starting.

The **Full** and **Episodes** radio buttons determine whether metadata is downloaded when the REFRESH button is selected (which fires off a query to iPlayer to retrieve. I _have_ mentioned it's quite slow, haven't I?)

![image](https://github.com/WookieeNo1/Get_iPlayer_Downloader/assets/83819273/f7fff79a-f0f8-4f97-8638-d5e87de55acb)

**All** will always download episodes, ignoring any previous downloads.

**New Only** will only download new items.

![image](https://github.com/WookieeNo1/Get_iPlayer_Downloader/assets/83819273/162bbb29-4b46-4ec2-8120-965c98f95c0b)

This section allows for the retrieval of external copies of the named options. All except Track Listing are (usually) embedded in the final file, but this allows for later use in whatever media player you're using (ie Kodi, Plex, et al)

![image](https://github.com/WookieeNo1/Get_iPlayer_Downloader/assets/83819273/6e96a1a1-c68b-416c-807d-ee058e0c63f7)

In the Type section the Radio buttons allow for the filtering of the main grid display. Note that this will clear any existing selections.
The Drop-Down boxes allow the selection of the *maximum* quality for each type of episode.

![image](https://github.com/WookieeNo1/Get_iPlayer_Downloader/assets/83819273/18cb7bdd-b951-44f2-a660-f25320b73348)

The Output Directory Text Box is currently read only and shows the value from the OUTPUT parameter.  WPF does not currently provided a native Directory Selector, and (in the interest of getting this release out) I've not put any code behind this - it just shows you _where_ the base directory for your saved files.

The **Download** button serves 2 purposes (currently).  If no selections have been made, a dialog will ask for confirmation to select all, and then return to the main display for any other actions required. If selections exist, it will instead generate a batch file <PID>.bat in the OUTDIR directory.


Finally - The DataGrid itself can be sorted on all columns - The Length column is a kludge to work -it will be fixed later
