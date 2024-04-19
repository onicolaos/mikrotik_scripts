# sample script to send email and telegram messages in mikrotik ros7

#change this to your email
:global emailEnabled true
:global notificationto "Your Name <your.email@example.com>"
:global notificationsubjectprefix ([/system identity get name] . " Alert:")

# Set variables for Telegram notifications
:global telegramEnabled true
:global telegramToken "9876543210:ZYXabc123DEF456GHI789JKL"
:global telegramChatIds {"1234567890"}

#send email, telegram but check if we have sent with the same subject in the last 10 minutes, to prevent spamming
:global sendnotification do={
:global notificationto
:global notificationsubjectprefix

:if ($emailEnabled = true) do={
	:local checklastemail [/log print count-only where message~"sent .*$subject.*" time>( [/system clock get time] - 10m )]
	#:put "clm $checklastemail"
	:if ($checklastemail<1) do={
	/tool e-mail send to="$notificationto" subject="$notificationsubjectprefix $subject" body="$body"
	:delay 10s
	} else={
	:log info "Already sent such email on the last 10 minutes"
	}
}

:if ($telegramEnabled = true) do={
:foreach chatId in=$telegramChatIds do={
:local checklasttelegram [/log print count-only where message~"Sent-telegram-.*$chatId.*$subject.*" time>( [/system clock get time] - 10m )]
:if ($checklasttelegram<1) do={

	:local MsgBody ($subject . ":\n\n" . $body)
	:local urlencodedMsgBody
	
	:for i from=0 to=([:len $MsgBody] - 1) do={
	:local char [:pick $MsgBody $i]
	:if ($char = " ") do={
	:set urlencodedMsgBody ($urlencodedMsgBody . "%20")
	} else={
	:if ($char = "-") do={
	:set urlencodedMsgBody ($urlencodedMsgBody . "%2D")
	} else={
	:if ($char = ":") do={
	:set urlencodedMsgBody ($urlencodedMsgBody . "%3A")
	} else={
	:if ($char = "/") do={
	:set urlencodedMsgBody ($urlencodedMsgBody . "%2F")
	} else={
	:if ($char = "&") do={
	:set urlencodedMsgBody ($urlencodedMsgBody . "%26")
	} else={
	:if ($char = "?") do={
	:set urlencodedMsgBody ($urlencodedMsgBody . "%3F")
	} else={
	:if ($char = "=") do={
	:set urlencodedMsgBody ($urlencodedMsgBody . "%3D")
	} else={
	:if ($char = "\n") do={
	:set urlencodedMsgBody ($urlencodedMsgBody . "%0A")
	} else={
	:set urlencodedMsgBody ($urlencodedMsgBody . $char)
	} } } } } } } } }

	:local url ("https://api.telegram.org/bot" . $telegramToken . "/sendMessage?chat_id=" . $chatId . "&text=" . $urlencodedMsgBody)

	:local filename ("telegram_" . $chatId . ".json")
	/tool fetch url=$url mode=https output=file dst-path=$filename
	:delay 3s
	:local fetchContents [:tostr [/file get $filename contents]]
	:if ($fetchContents~"ok\":true") do={
		:log info ("Sent-telegram-" . $chatId . "-" . $subject)
	}
	:if ([:len [/file find name=$filename]] > 0) do={
		/file remove $filename
	}
	} else={
	:log info "Already sent such telegram on the last 10 minutes"
	}
}
}
}

:local count 1
:local msgbody "There is only $count connected clients."
$sendnotification subject="Important network update" body=$msgbody
