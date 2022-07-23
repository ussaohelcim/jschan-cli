param($style )
#region Utilities

enum JschanLocation {
	Home  # main location where list jschan instances
	InstanceHome # main location where lists an instance board list
	ChooseBoard	# board catalog
	ChooseThread  # location that shows a thread
	Thread #
	NewThread # location to create a new thread
	NewReply # location to reply a thread
}

function Get-JsonFromUrl { param ($urljson)
	$ProgressPreference = 'SilentlyContinue'
	$resp = Invoke-WebRequest -Uri $urljson
	return (($resp.content) | ConvertFrom-Json -Depth 20)
}

function Get-WindowSize {
	return (Get-Host).UI.RawUI.WindowSize.Width
}
function Get-InstancesJson{
	return (Get-Content .\instances.json | ConvertFrom-Json)
}
function Write-TerminalWide{ param($char,$color)
	# TODO rename function
	$size = (Get-Host).UI.RawUI.WindowSize.Width
	$r = ""
	for($i = 0; $i -lt $size ; $i++){
		$r += $char
	}
	Write-Host $r -ForegroundColor $color
}

#endregion

#region 
#endregion

function Write-Overboard {
	Clear-Host
	
	$overboard = Get-JsonFromUrl -urljson "$root/catalog.json"
	[System.Collections.ArrayList]$threadsInverted = @()
	$catalog = $overboard.threads

	for ($i = $catalog.Count - 1; $i -ge 0 ; $i--) {
		Write-Host "[$i]" -BackgroundColor ($selectedStyle.selection) -NoNewline
		Write-Host "" $catalog[$i].board -NoNewline
		Write-PostInfo -post $catalog[$i]
		Write-PostMessage -post $catalog[$i]
		Write-TerminalWide -char "-" ($selectedStyle.separator)

		$null = $threadsInverted.Add(
			$catalog[$catalog.Count - $i - 1]
		)
	}

	Enter-Option -location ([JschanLocation]::ChooseThread) -payload $threadsInverted -overboard $true
}

function Write-PostInfo{ param($post)
	$info = @{
		name = $post.name
		subject = $post.subject ?? ""
		date = $post.date 
		postId = $post.postId
		replyposts = $post.replyposts
		files = $post.files
	}

	$no = $info.postId
	Write-Host "" $info.name "" -ForegroundColor ($selectedStyle.name) -NoNewline
	Write-Host $info.date "no."$no -NoNewline

	$quotes = " "

	foreach($quote in $post.backlinks)
	{
		$id = $quote.postId
		$quotes += ">>$id "
	}

	Write-Host $quotes -ForegroundColor ($selectedStyle.backgroundText)

	if($info.files.count -gt 0){
		foreach($file in $info.files){
			$filename = $file.filename
			$og = $file.originalFilename
			$_link = "$root/file/$filename"
			Write-Host $og ">" $_link -ForegroundColor ($selectedStyle.file)
		}
	}

}

function Write-PostMessage{ param($post)
	$txt = $post.nomarkup ?? " "

	$nl = [System.Environment]::NewLine
	[string[]]$txt = $txt.Split($nl)

	foreach($linha in $txt)
	{
		[string]$line = $linha
		if ($linha.startswith(">>")) {
			Write-Host $line -ForegroundColor ($selectedStyle.quote) 
		}elseif($linha.startswith(">")){
			Write-Host $line -ForegroundColor ($selectedStyle.greenText) 
		}elseif ($linha.startswith("==")) {
			$line = $line.Replace('==',"")
			Write-Host $line -ForegroundColor ($selectedStyle.Title) 
		}elseif ($linha.startswith("http")) {
			Write-Host $line -ForegroundColor ($selectedStyle.link) 
		}elseif ($linha.startswith("<")) {
			Write-Host $line -ForegroundColor ($selectedStyle.pinkText) 
		}else {
			Write-Host $line -ForegroundColor ($selectedStyle.text) 
		}
	}
}

function Write-ErrorMessage { param($errMessage)
	Write-Host $errMessage
	Start-Sleep -Seconds 3
	
}

function Write-BoardCatalog { param ($board)
	#$board = http://fatchan.gitgud.site/jschan-docs/#board-list
	#$catalog = https://fatchan.org/{board}/catalog.json
	
	Clear-Host
		
	$_boardTag = $board._id
	$link = "$root/$_boardTag/catalog.json"
	Write-Host $link
	$catalog = Get-JsonFromUrl -urljson $link

	[System.Collections.ArrayList]$threadsInverted = @()

	for ($i = $catalog.Count - 1; $i -ge 0 ; $i--) {
		Write-Host "[$i]" -BackgroundColor ($selectedStyle.selection)  -NoNewline
		Write-PostInfo -post $catalog[$i]
		Write-PostMessage -post $catalog[$i]
		Write-Host "Replies:" $catalog[$i].replyposts -ForegroundColor ($selectedStyle.backgroundText)
		Write-TerminalWide -char "-" ($selectedStyle.separator)
		$null = $threadsInverted.Add(
			$catalog[$catalog.Count - $i - 1]
		)
	}

	Enter-Option -location ([JschanLocation]::ChooseThread) -payload $threadsInverted
}

function Write-Thread { param($thread)
	Clear-Host

	Write-Host "[OP]" -NoNewline
	Write-PostInfo $thread

	Write-PostMessage $thread
	
	foreach($reply in $thread.replies){
		Write-TerminalWide -char "-" ($selectedStyle.separator)
		Write-PostInfo $reply
		Write-PostMessage $reply
	}

	Enter-Option ([JschanLocation]::Thread) $thread
}

function Write-Home {
	#script home
	Clear-Host

	$instancesJSON = Get-InstancesJson

	Write-Host "Welcome to jschan-cli."

	$num = 0
	foreach($chan in $instancesJSON){
		Write-Host "[$num]" -BackgroundColor ($selectedStyle.selection) -NoNewline
		Write-Host "" $chan.name "`t" -NoNewline
		Write-Host $chan.link 
		$num++
	}
	Write-Host "[new] = add new instance"

	Enter-Option -location ([JschanLocation]::Home) -payload $instancesJSON
}


function Write-InstanceHome { param($url)
	Clear-Host

	$boardList = (Get-JsonFromUrl -urljson "$url/boards.json?local_first=true").boards

	$opNum = 0

	foreach($board in $boardList)
	{
		Write-Host "[$opNum]" -BackgroundColor DarkRed -NoNewline
		Write-Host " `t" $board._id "`t" -NoNewline
		Write-Host $board.settings.description -ForegroundColor DarkGray
		$opNum++
	}

	Write-Host "[over]" -BackgroundColor DarkRed -NoNewline
	Write-Host "`t Overboard `t" 

	Enter-Option -location ([JschanLocation]::ChooseBoard) -payload $boardList
}

function Get-RandomString {
	return (-join ((65..90) + (97..122) | Get-Random -Count 20 | ForEach-Object {[char]$_}))
}

function New-Post{ param($thread)
	$board = $thread.board
	$postId = $thread.postId
	Write-Host $root $board $postId

	$link_ToPost = "$root/forms/board/$board/post"
	
	$header =  @{
		Referer = "$root/$board/index.html" 
		origin = "$root"
	}

	$body = @{
		thread = $postId
		name = ""
		message = ""
		subject = ""
		email = ""
		postpassword = ""
	}

	$pass = Get-RandomString
	$body.name = Read-Host "name [anon]"
	$x = ""
	$message = ""

	Write-Host "Write a line with only a 'x' to finish the message" -ForegroundColor Red
	while ('x' -ne $x) {
		$x = Read-Host "message ['']"

		if('x' -ne $x)
		{
			$message += $x + ([System.Environment]::NewLine)
		}
	}

	$body.message = $message

	$body.email = Read-Host "email ['']"

	$body.subject = Read-Host "subject ['']"
	$pwsrd = Read-Host "password ['$pass']"
	$body.postpassword = $pwsrd -eq '' ? $pass : $pwsrd

	Write-TerminalWide '-' ($selectedStyle.separator)
	Write-PostInfo -post (@{
		name = $body.name -eq '' ? "anon" : $body.name
		files = @()
		replyposts = @()
		postId = 0
		date = "NOW"
	})
	Write-PostMessage -post (@{
		nomarkup = $body.message
	})
	Write-TerminalWide '-' ($selectedStyle.separator)

	$choosed = $false
	
	while (!$choosed) {
		$op = Read-Host "Send post to thread $postId ? [y,n]"
		
		$choosed = $op -eq "y" -or $op -eq "n"
	}

	if('y' -eq $op)
	{
		Invoke-WebRequest -Uri $link_ToPost -Form $body -Method Post -Headers $header
		if($null -eq $postId)	{
			Clear-Host
			Write-Host "Thread created..."
			Start-Sleep -Seconds 3
			Write-BoardCatalog -board (@{_id = $board})
		}else{
			Write-Thread -thread (Get-JsonFromUrl "$root/$board/thread/$postId.json")
		}	
	}
	else{
		Write-Thread -thread (Get-JsonFromUrl "$root/$board/thread/$postId.json")
	}

}


function New-Instance{ 
	$name = Read-Host "Instance name"
	$link = Read-Host "Instance url (without the last '/')"

	$instances = Get-InstancesJson

	$instances += @{
			name = $name
			link = $link
		}
	
	Set-Content instances.json ( $instances | ConvertTo-Json)

}

function Enter-Option { param([JschanLocation]$location,$payload, $overboard)
	Write-TerminalWide -char "-" ($selectedStyle.separator)

	switch ($location) {
		([JschanLocation]::Home) { 
			# choose instance
			# $location = [JschanLocation]::Home 
			# $payload = instances.json

			Write-Host "Choose a " -NoNewline
			Write-Host "[instance]" -BackgroundColor ($selectedStyle.selection) -NoNew

			$op = Read-Host " "

			$script:root = $payload[$op].link

			if($op -eq "new"){
				New-Instance
				Write-Home
			}
			else{
				try {
					Write-InstanceHome -url ($payload[$op].link) 
				}
				catch {
					Write-ErrorMessage "Wrong option..."
					Write-Home
				}
			}

			break
		}
		([JschanLocation]::ChooseBoard) {
			# $location = [JschanLocation]::ChooseBoard 
			# $payload = (boardlist).boards http://fatchan.gitgud.site/jschan-docs/#board-list

			Write-Host "Press enter go back to choose an instance..." -ForegroundColor ($selectedStyle.backgroundText)

			Write-Host "Choose a " -NoNewline
			Write-Host "[board]" -BackgroundColor ($selectedStyle.selection) -NoNewline

			$op = Read-Host " "

			if($op -eq "back" -or $op -eq "")
			{
				Write-Home
			}elseif($op -eq "over"){
				Write-Overboard
			}
			else {
				try {
					Write-BoardCatalog -board ($payload[$op])
				}
				catch {
					Write-ErrorMessage "Something went wrong"
					Write-Home
				}
			}
		
			break
		}
		([JschanLocation]::ChooseThread) {
			# last = Write-BoardCatalog
			# $location = [JschanLocation]::ChooseThread 
			# $payload = catalog http://fatchan.gitgud.site/jschan-docs/#board-catalog

			#https://fatchan.org/{board}/thread/{threadId}.json

			if($null -eq $overboard)
			{
				Write-Host "'n' to create a new thread." -ForegroundColor ($selectedStyle.backgroundText)
			}

			Write-Host "'h' to go back to $root ." -ForegroundColor ($selectedStyle.backgroundText)
			Write-Host "Press enter to refresh the catalog." -ForegroundColor ($selectedStyle.backgroundText)
			Write-Host "Choose a " -NoNewline
			Write-Host "[thread]" -BackgroundColor ($selectedStyle.selection) -NoNewline
			$op = Read-Host " "

			$board = $payload[$op].board
			$postId = $payload[$op].postId
		
			if($null -eq $overboard -and 'n' -eq $op){
				New-Post (@{
					board = $payload[0].board
					postId = $null
				})
			}
			elseif('h' -eq $op){
				Write-InstanceHome -url $root
			}
			elseif ('' -eq $op) {
				Write-BoardCatalog -board (@{_id = $payload[0].board})
			}
			else{
				try {
					Write-Thread -thread (Get-JsonFromUrl "$root/$board/thread/$postId.json")
				}
				catch {
					Write-Error "Wrong option..."
					Write-BoardCatalog -board (@{_id = $payload.board})
				}
			}

			
		}
		([JschanLocation]::Thread) {
			# $payload = thread http://fatchan.gitgud.site/jschan-docs/#thread
			
			Write-Host "'r' to reply this thread." -ForegroundColor ($selectedStyle.backgroundText)
			Write-Host "'c' to go back to catalog." -ForegroundColor ($selectedStyle.backgroundText)
			Write-Host "'h' to go back to instance selection." -ForegroundColor ($selectedStyle.backgroundText)
			Write-Host "Press enter to refresh the thread." -ForegroundColor ($selectedStyle.backgroundText)

			$op = Read-Host "Choose an option"

			switch ($op) {
				'h' { 
					Write-Home
				}
				'c' { 
					Write-BoardCatalog -board (@{_id = $payload.board})
				}
				'r' { 
					New-Post -thread $payload
				}
				Default {
					$board = $payload.board
					$postId = $payload.postId
					Write-Thread -thread (Get-JsonFromUrl "$root/$board/thread/$postId.json")
				}
			}
			break
		}
		Default {}
	}

}

function Get-Style{ param($name)
	$themes = Get-Content .\themes.json | ConvertFrom-Json
	return $themes.$name ?? $themes.default
}

$script:root = ""

$script:selectedStyle = Get-Style -name $style

Write-Home
