#!/bin/bash

sudo -v

dev=false
debug=false

for arg in "${@}"; do
  [ "${arg}" = "--dev" ] && dev=true
  [ "${arg}" = "--debug" ] && debug=true
done

log_redirects="/dev/null"

[ "${debug}" = true ] && log_redirects="/dev/stdout"

reset="\e[0m"
bold="\x1b[1m"
dim="\x1b[2m"
italic="\x1b[3m"
underline="\x1b[4m"
blink="\x1b[5m"
inverse="\x1b[7m"
hidden="\x1b[8m"
strikethrough="\x1b[9m"

black="\e[30m"
red="\e[31m"
green="\e[32m"
yellow="\e[33m"
blue="\e[34m"
magenta="\e[35m"
cyan="\e[36m"
white="\e[37m"
gray="\e[90m"

zapret_version="72.9"

send_metrics() {
  echo ""
  echo -e "  ${gray}Would you like to share the results with ${blue}Keift${gray}?${reset}"
  echo -ne "  ${gray}This helps us improve this tool. [${green}Y${gray}/${red}N${gray}] ${reset}"

  if [ -t 0 ]; then
    read metrics_answer
  else
    read metrics_answer < /dev/tty
  fi

  if [ "${metrics_answer,,}" = "y" ]; then
    echo ""
    echo -e "  ${gray}Thank you for your feedback.${reset}"

    local event="${1}"
    local unix_name=$(uname -a)
    local domain_response=$(curl --max-time 10 -sS -I "https://${blockcheck_domain}" 2>&1 | head -n 1)

    local payload=$(
      jq -n \
        --arg event "${event}" \
        --arg unix_name "${unix_name}" \
        --arg dns_resolver "${dns_resolver}" \
        --arg blockcheck_domain "${blockcheck_domain}" \
        --arg blockcheck_results "${blockcheck_results}" \
        --arg domain_response "${domain_response}" \
        --arg nfqws_options "${nfqws_options}" \
        '{
          event: $event,
          data: {
            unix_name: $unix_name,
            dns_resolver: $dns_resolver,
            blockcheck_domain: $blockcheck_domain,
            blockcheck_results: $blockcheck_results,
            domain_response: $domain_response,
            nfqws_options: $nfqws_options
          }
        }'
    )

    curl --max-time 10 -X POST https://metrics--api.keift.co/zapret \
      -H "Content-Type: application/json" \
      -d "${payload}" &>"${log_redirects}"
  else
    echo ""
    echo -e "  ${gray}That's okay, nothing was shared.${reset}"
  fi
}

clear

echo ""
echo -e "  ${blue}Keift ${cyan}Install Zapret${reset}"
echo ""

if ! command -v systemctl &>/dev/null; then
  echo -e "  ${red}Error: This only works on Systemd devices.${reset}"
  echo ""

  exit 1
fi

# 1. Install dependencies

echo -e "  ${gray}Installing dependencies...${reset}"

if command -v apt &>/dev/null; then
  export DEBIAN_FRONTEND="noninteractive"

  sudo apt update -y &>"${log_redirects}"

  sudo apt install -y bind9-dnsutils &>"${log_redirects}"
  sudo apt install -y curl &>"${log_redirects}"
  sudo apt install -y jq &>"${log_redirects}"
  sudo apt install -y nftables &>"${log_redirects}"
  sudo apt install -y unzip &>"${log_redirects}"
  sudo apt install -y wget &>"${log_redirects}"
elif command -v dnf &>/dev/null; then
  sudo dnf makecache -y &>"${log_redirects}"

  sudo dnf install -y bind-utils &>"${log_redirects}"
  sudo dnf install -y curl &>"${log_redirects}"
  sudo dnf install -y jq &>"${log_redirects}"
  sudo dnf install -y nftables &>"${log_redirects}"
  sudo dnf install -y unzip &>"${log_redirects}"
  sudo dnf install -y wget &>"${log_redirects}"
elif command -v pacman &>/dev/null; then
  sudo pacman -Syu --noconfirm &>"${log_redirects}"

  sudo pacman -S --noconfirm bind &>"${log_redirects}"
  sudo pacman -S --noconfirm curl &>"${log_redirects}"
  sudo pacman -S --noconfirm jq &>"${log_redirects}"
  sudo pacman -S --noconfirm nftables &>"${log_redirects}"
  sudo pacman -S --noconfirm unzip &>"${log_redirects}"
  sudo pacman -S --noconfirm wget &>"${log_redirects}"
elif command -v zypper &>/dev/null; then
  sudo zypper -n refresh &>"${log_redirects}"

  sudo zypper -n install bind-utils &>"${log_redirects}"
  sudo zypper -n install curl &>"${log_redirects}"
  sudo zypper -n install jq &>"${log_redirects}"
  sudo zypper -n install nftables &>"${log_redirects}"
  sudo zypper -n install unzip &>"${log_redirects}"
  sudo zypper -n install wget &>"${log_redirects}"
else
  echo -e "  ${red}Error: Unsupported package manager.${reset}"
  echo ""

  exit 1
fi

# 2. Change DNS settings

echo -e "  ${gray}DNS settings are being changed...${reset}"

if dig -p 853 +tls +tls-hostname=one.one.one.one +tries=1 @1.1.1.1 &>"${log_redirects}" \
  || dig -p 853 +tls +tls-hostname=base.dns.mullvad.net +tries=1 @194.242.2.4 &>"${log_redirects}" \
  || dig -p 853 +tls +tls-hostname=dns.google +tries=1 @8.8.8.8 &>"${log_redirects}" \
  || dig -p 853 +tls +tls-hostname=common.dot.dns.yandex.net +tries=1 @77.88.8.8 &>"${log_redirects}"; then
  if command -v apt &>/dev/null; then
    sudo apt install -y systemd-resolved &>"${log_redirects}"

    sudo apt purge -y dnscrypt-proxy &>"${log_redirects}"
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y systemd-resolved &>"${log_redirects}"

    sudo dnf remove -y dnscrypt-proxy &>"${log_redirects}"
  elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm systemd-resolved &>"${log_redirects}"

    sudo pacman -Rns --noconfirm dnscrypt-proxy &>"${log_redirects}"
  elif command -v zypper &>/dev/null; then
    sudo zypper -n install systemd-resolved &>"${log_redirects}"

    sudo zypper -n remove -u dnscrypt-proxy &>"${log_redirects}"
  else
    echo -e "  ${red}Error: Unsupported package manager.${reset}"
    echo ""

    exit 1
  fi

  dns_resolver="systemd-resolved"

  sudo systemctl enable systemd-resolved &>"${log_redirects}"
  sudo systemctl start systemd-resolved

  sudo tee /etc/systemd/resolved.conf &>/dev/null << EOF
[Resolve]
DNS=1.1.1.1#one.one.one.one
DNS=2606:4700:4700::1111#one.one.one.one
DNS=1.0.0.1#one.one.one.one
DNS=2606:4700:4700::1001#one.one.one.one

DNS=194.242.2.4#base.dns.mullvad.net
DNS=2a07:e340::4#base.dns.mullvad.net
DNS=194.242.2.2#dns.mullvad.net
DNS=2a07:e340::2#dns.mullvad.net

DNS=8.8.8.8#dns.google
DNS=2001:4860:4860::8888#dns.google
DNS=8.8.4.4#dns.google
DNS=2001:4860:4860::8844#dns.google

DNS=77.88.8.8#common.dot.dns.yandex.net
DNS=2a02:6b8::feed:0ff#common.dot.dns.yandex.net
DNS=77.88.8.1#common.dot.dns.yandex.net
DNS=2a02:6b8:0:1::feed:0ff#common.dot.dns.yandex.net

DNSOverTLS=yes
EOF

  sudo chattr -i /etc/resolv.conf &>"${log_redirects}"

  [ -e /run/systemd/resolve/stub-resolv.conf ] && sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

  sudo systemctl restart systemd-resolved
else
  if command -v apt &>/dev/null; then
    sudo apt install -y systemd-resolved &>"${log_redirects}"
    sudo apt install -y dnscrypt-proxy &>"${log_redirects}"
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y systemd-resolved &>"${log_redirects}"
    sudo dnf install -y dnscrypt-proxy &>"${log_redirects}"
  elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm systemd-resolved &>"${log_redirects}"
    sudo pacman -S --noconfirm dnscrypt-proxy &>"${log_redirects}"
  elif command -v zypper &>/dev/null; then
    sudo zypper -n install systemd-resolved &>"${log_redirects}"
    sudo zypper -n install dnscrypt-proxy &>"${log_redirects}"
  else
    echo -e "  ${red}Error: Unsupported package manager.${reset}"
    echo ""

    exit 1
  fi

  dns_resolver="dnscrypt-proxy"

  sudo systemctl enable systemd-resolved &>"${log_redirects}"
  sudo systemctl start systemd-resolved

  sudo systemctl enable dnscrypt-proxy &>"${log_redirects}"
  sudo systemctl start dnscrypt-proxy

  sudo tee /etc/systemd/resolved.conf &>/dev/null << EOF
[Resolve]
DNS=127.0.0.1:5300
DNS=[::1]:5300

DNSOverTLS=no
EOF

  sudo chattr -i /etc/resolv.conf &>"${log_redirects}"

  [ -e /run/systemd/resolve/stub-resolv.conf ] && sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

  sudo systemctl restart systemd-resolved

  sudo tee /etc/dnscrypt-proxy/dnscrypt-proxy.toml &>/dev/null << EOF
listen_addresses = ["127.0.0.1:5300", "[::1]:5300"]

server_names = ["cloudflare", "cloudflare-ipv6", "mullvad-base-doh", "mullvad-doh", "google", "google-ipv6", "yandex", "yandex-ipv6"]

[sources]
  [sources."public-resolvers"]
  urls = ["https://raw.github.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md", "https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md"]
  minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3"
  cache_file = "/var/cache/dnscrypt-proxy/public-resolvers-v3.md"
EOF

  sudo systemctl restart dnscrypt-proxy
fi

# 3. Download Zapret

echo -e "  ${gray}Downloading Zapret...${reset}"

sudo rm -rf /tmp/zapret
sudo rm -rf /tmp/zapret.zip

sudo wget -O /tmp/zapret.zip "https://github.com/bol-van/zapret/releases/download/v${zapret_version}/zapret-v${zapret_version}.zip" &>"${log_redirects}"

sudo unzip -d /tmp /tmp/zapret.zip &>"${log_redirects}"

sudo mv "/tmp/zapret-v${zapret_version}" /tmp/zapret

sudo rm -rf /tmp/zapret.zip

# 4. Prepare for installation

echo -e "  ${gray}Preparing for installation...${reset}"

printf "\n" | sudo /opt/zapret/uninstall_easy.sh &>"${log_redirects}"
sudo rm -rf /opt/zapret

printf "\n\n" | sudo /tmp/zapret/install_prereq.sh &>"${log_redirects}"
sudo /tmp/zapret/install_bin.sh &>"${log_redirects}"

# 5. Do Blockcheck

echo -e "  ${gray}Blockcheck is being performed, this may take a few minutes...${reset}"

country_code=$(curl --max-time 10 -s https://ipinfo.io/country)

blockcheck_domain="discord.com"

[ "${country_code}" = "RU" ] && blockcheck_domain="discord.com"
[ "${country_code}" = "TR" ] && blockcheck_domain="discord.com"
[ "${country_code}" = "IN" ] && blockcheck_domain="tiktok.com"

if [ "${dev}" = true ]; then
  nfqws_options="--dpi-desync-badseq-increment=0 --dpi-desync-fooling=md5sig --dpi-desync-split-seqovl=1 --dpi-desync=fakeddisorder --dpi-desync-ttl=1 --dpi-desync-autottl=-5 --dpi-desync-split-pos=1"
else
  blockcheck_results=$(printf "${blockcheck_domain}\n\n\n\n\n\n\n\n" | sudo /tmp/zapret/blockcheck.sh 2>"${log_redirects}")

  [ "${debug}" = true ] && echo "${blockcheck_results}"

  nfqws_options=$(echo "${blockcheck_results}" | sed -n "/^\* SUMMARY/,\$p" | grep -E "curl_test_http|curl_test_https_tls12" | grep "ipv4 ${blockcheck_domain} : nfqws" | sed "s/.*nfqws //" | tr " " "\n" | tac | awk -F= "NF && !seen[\$1]++" | tac | tail -n 62 | tr "\n" " " | sed "s/[[:space:]]*\$//")
fi

if [[ "${blockcheck_results}" == *"nftables queue support is not available"* ]]; then
  printf "\n" | sudo /opt/zapret/uninstall_easy.sh &>"${log_redirects}"
  sudo rm -rf /opt/zapret
  sudo rm -rf /tmp/zapret

  echo -e "  ${red}Error: You need to update your system.${reset}"

  if command -v apt &>/dev/null; then
    echo -e "         ${red}Use: ${white}sudo apt update -y${reset}"
    echo -e "              ${white}sudo apt upgrade -y${reset}"
  elif command -v dnf &>/dev/null; then
    echo -e "         ${red}Use: ${white}sudo dnf makecache -y${reset}"
    echo -e "              ${white}sudo dnf upgrade -y${reset}"
  elif command -v pacman &>/dev/null; then
    echo -e "         ${red}Use: ${white}sudo pacman -Syu --noconfirm${reset}"
  elif command -v zypper &>/dev/null; then
    echo -e "         ${red}Use: ${white}sudo zypper -n refresh${reset}"
    echo -e "              ${white}sudo zypper -n update${reset}"
  fi

  echo ""

  exit 1
fi

if echo "${blockcheck_results}" | grep -q "curl_test_http ipv4 ${blockcheck_domain} : working without bypass" \
  && echo "${blockcheck_results}" | grep -q "curl_test_https_tls12 ipv4 ${blockcheck_domain} : working without bypass"; then
  printf "\n" | sudo /opt/zapret/uninstall_easy.sh &>"${log_redirects}"
  sudo rm -rf /opt/zapret
  sudo rm -rf /tmp/zapret

  echo -e "  ${gray}No access restrictions were detected.${reset}"

  send_metrics ZAPRET_NO_ACCESS_RESTRICTIONS_WERE_DETECTED

  echo ""

  exit 0
fi

# 6. Install Zapret

echo -e "  ${gray}Installing Zapret...${reset}"

printf "Y\n\n\n\n\n\n\nY\n\n\n\n\n" | sudo /tmp/zapret/install_easy.sh &>"${log_redirects}"

sudo sed -i "/^NFQWS_OPT=\"/,/^\"/c NFQWS_OPT=\"${nfqws_options} --hostlist=/opt/zapret/hostlist.txt --hostlist-auto=/opt/zapret/ipset/zapret-hostlist-auto.txt\"" /opt/zapret/config

sudo touch /opt/zapret/hostlist.txt

sudo tee /opt/zapret/ipset/zapret-hostlist-auto.txt &>/dev/null << EOF
# Discord
discord.com
discord.net
discordapp.com
discordapp.net
discord.co
discord.dev
discord.gg
discord.gift
discord.media
discord.new

# Steam
steampowered.com
steamcommunity.com
steam-chat.com
steamcontent.com
steamstatic.com
steamusercontent.com
steamserver.net

# Roblox
roblox.com

# Others
EOF

sudo systemctl restart zapret

# 7. Finish the installation

echo -e "  ${gray}Zapret was successfully installed.${reset}"

sudo rm -rf /tmp/zapret

send_metrics ZAPRET_INSTALLATION_SUCCESSFUL

echo ""