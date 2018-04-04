#
# powercli-disk-usage
#
# Description: Check virtual machines disk usage and generate an HTML report that list all the VMs in a warning status.
#
# CHANGELOG
#
# v1.0 : Initial release
#

#VIServer that manages the virtual machines (vCenter/ESXi)
$VMWARE = "**YourVIServer**"
#HTML report filename
$REPORT = "disk-usage.html"
#VM folders to check, to avoid a full (and long) infrastructure check
$FOLDERS = @("TEST","TEMPLATE")
#Disk Usage warning threshold
$WARNING=25

function ConnectVMWARE()
{
	try
	{
		Connect-VIServer $VMWARE -ErrorAction Stop
		return $true
	}	
	catch
	{
		return $false
	}
}

function CheckVMs()
{
	$checkedVMs = foreach($vm in $vms)
	{
		$ip = $vm.ExtensionData.Guest.IpAddress
		foreach($drive in $vm.ExtensionData.Guest.Disk)
		{
			$driveName = $drive.DiskPath
			$freeSpace = [math]::Round(($drive.FreeSpace/1GB),2)
			$capacity = [math]::Round(($drive.Capacity/1GB),2)
			$percent = [math]::Round(($freeSpace/$capacity)*100)

			if ($percent -gt $WARNING) { continue }
			$props = @{'Name'=$vm.Name
				'Drive'=$driveName}
			
			$obj = New-Object -Type PSCustomObject -Property @{
				'Name' = $vm.Name
				'Ip' = $ip
				'Drive' = $driveName
				'Capacity' = $capacity
				'FreeSpace' = $freeSpace
				'FreePercent' = $percent
			}
			
			$obj | Select Drive, Capacity, FreeSpace, FreePercent | ConvertTo-HTML -As LIST -Fragment -PreContent "<h2 style=color:red>$vm ($ip)</h2>" | Out-String
		}# foreach $drive
	}# foreach $vm
	
	$checkedVMs
}

###MAIN###

$connected = ConnectVMWARE
if(-Not $connected)
{
	exit
}

$date = Get-Date -Format "F"
$head = "<style>BODY{background-color:#2b5797;color:white}</style>"
$body = "<H1>VM DISK USAGE $date</H1>"
foreach($location in $FOLDERS)
{
	$vms = Get-VM -Location "$location"
	$check = CheckVMs
	if (!$check)
	{
		$check = "<h2 style=color:limegreen>OK!</h2>"
	}
	$raw = $raw + "<H1>$location</H1>" + $check
}

#Convert the raw report in a HTML report
ConvertTo-HTML -head $head - body $body -PostContent $raw | Out-File "$REPORT"

#Disconnect from $VMWARE
Disconnect-VIServer -Server * -Force -Confirm:$false