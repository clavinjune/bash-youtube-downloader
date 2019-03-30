#! /bin/bash

# author Clavin June
# github https://www.github.com/ClavinJune

BOLD="\e[1m"
BLINK="\e[5m"
RESET="\e[0m"

FGRED="\e[31m"
FGGREEN="\e[32m"

splash () {
  echo "        _   _               _      __          "
  echo "  _   _| |_| |__   __ _ ___| |__   \ \         "
  echo " | | | | __| '_ \ / _\` / __| '_ \   \ \        "
  echo " | |_| | |_| |_) | (_| \__ \ | | |  / /        "
  echo "  \__, |\__|_.__/ \__,_|___/_| |_| /_/ _____ "
  echo "  |___/                          1.0.0|>____|"
  echo
}

usage () {
  echo " Usage: $0 <youtube-video-id>"
  echo " example: $0 cdwal5Kw3Fc"
}

logging () {
  sleep $1
  if [ "$2" = "ok" ]; then
    echo -en " $BOLD[$RESET${FGGREEN}${BOLD}OK${RESET}$BOLD]$RESET   "
  elif [ "$2" = "err" ]; then
    echo -en " $BOLD[$RESET${FGRED}${BOLD}ERR${RESET}$BOLD]$RESET  "
  elif [ "$2" = "info" ]; then
    echo -en " $BOLD[$RESET${FGGREEN}${BOLD}INFO${RESET}$BOLD]$RESET "
  fi 
  echo -e "$3"
}

main () {
  url0="\x68\x74\x74\x70\x73\x3a\x2f\x2f\x77\x77\x77\x2e"
  url1="\x79\x6f\x75\x74\x75\x62\x65\x2e\x63\x6f\x6d\x2f"
  url2="\x67\x65\x74\x5f\x76\x69\x64\x65\x6f\x5f\x69\x6e\x66\x6f"
  url3="\x3f\x76\x69\x64\x65\x6f\x5f\x69\x64\x3d"
  url4="\x77\x61\x74\x63\x68"
  url5="\x3f\x76\x3d"
  url6="\x79\x6f\x75\x74\x75\x2e\x62\x65\x2f"


  url="$(echo -e $url0$url1$url2$url3 | cat)$1"
  # echo -e $url3 | cat
  validUrl="$(echo -e $url0$url1$url4$url5 | cat)$1"

  logging .5 "info" "Validating youtube video id.."

  statusCode=$(curl -s -o /dev/null -w "%{http_code}" $validUrl)

  if [ "$statusCode" != "200" ]; then
    logging 0 "err" "Video id is not valid"
    exit 1
  else
    logging 0 "ok" "Video id is valid"
  fi

  loggingUrl="$(echo -e $url0$url6 | cat)$1"

  logging .5 "info" "Getting Video Info from $loggingUrl.."
  videoInfoFile=$(wget -qO- $url)

  declare -A videoInfo

  logging .5 "info" "Converting video info to JSON.."
  while read key value
  do
    videoInfo["$key"]="$value"
  done < <(awk -F'&' '{for(i=1;i<=NF;i++) {print $i}}' <<< $videoInfoFile | awk -F'=' '{print $1" "$2}')

  logging .5 "info" "Decoding url special character.."
  playerResponse=${videoInfo["player_response"]}
  decodedPlayerResponse=$(printf "%b" "${playerResponse//%/\\x}")

  logging .5 "info" "Reading video status.."
  status=$(echo $decodedPlayerResponse | jq ".playabilityStatus" | jq ".status" | tr "\"" " " | tr -d "[:space:]")

  if [ "$status" = "UNPLAYABLE" ]; then
    logging 0 "err" "Video is undownloadable by this script"
    exit 1
  elif [ "$status" = "" ]; then
    logging 0 "err" "Video is unavailable"
    exit 1
  fi

  logging 0 "ok" "Video status downloadable"

  result=($(echo $decodedPlayerResponse | jq ".streamingData" | jq ".formats" | jq ".[] | .url, .qualityLabel"))

  title=$(echo $decodedPlayerResponse | jq ".videoDetails" | jq ".title" | tr "\"" " " | tr -d "[:space:]" | tr "+" " ")

  declare -A links

  logging .5 "info" "Listing all donwloadable resolutions.."
  for ((i = 0 ; i < ${#result[@]}-1 ; i+=2))
  do
    url=$(echo ${result[$i]} | tr "\"" " " | tr -d "[:space:]")
    resolution=$(echo ${result[$i+1]} | tr "\"" " " | tr -d "[:space:]")
    links["$resolution"]="$url"
  done

  if [ ${#links[@]} -eq 0 ]; then
    logging 0 "err" "Video is undownloadable by this script"
    exit 1
  fi

  echo -e " Available resolution: $BOLD${!links[@]}$RESET"

  while true
  do
    echo -ne " Choose: "
    read reso

    if [ -n "${links[$reso]}" ]; then
      break
    fi
  done

  if [ "${links["$reso"]}" = "" ]; then
    logging 0 "err" "Resolution is not available"
    exit 1
  fi

  target="$title-$reso.webm"
  logging .5 "info" "Downloading $BOLD$title -> $target$RESET.."
  wget ${links["$reso"]} --show-progress -qO "$target"
  logging 0 "ok" "$target is downloaded!"

  exit 0
}

if [ "$(which jq 2>/dev/null)" = "" ]; then
  logging 0 "err" "This script requires jq, please resolve and try again."
  exit 1
fi


splash

if [ $# -eq 0 ]; then
  usage
else
  main $1
fi

exit 1