#!/bin/sh

version=$(cat /etc/openwrt_release | grep DISTRIB_RELEASE | cut -d"'" -f2)
supported_versions="22.03.7 23.05.5 24.10.1"

is_supported=0
for supported in $supported_versions; do
    if [ "$version" = "$supported" ]; then
        is_supported=1
        break
    fi
done

if [ $is_supported -eq 0 ]; then
    echo "WARNING: OpenWrt version $version has not been tested with SEFTHY."
    echo "Supported versions are: $supported_versions"
    echo "Installation may not work correctly on this version."
    echo "Do you want to continue anyway? (y/N)"
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            echo "Continuing installation..."
            ;;
        *)
            echo "Installation aborted."
            exit 1
            ;;
    esac
fi

opkg update && 
opkg install \
 bash python3-pip python3-psutil python3-netifaces \
 sipcalc curl jq sqlite3-cli vxlan ip-full iperf3 iputils-arping \
 luci-lua-runtime micrond tar wireguard-tools || exit 1

pip install flask flask-sqlalchemy speedtest-cli waitress requests || exit 1

which unzip >/dev/null || opkg install unzip


mkdir /opt
for resource in "sefthy-wrt-config" "sefthy-wrt-gui" "sefthy-wrt-monitor" "sefthy-wrt-wh" "sefthy-wrt-velch"; do
  wget https://static.sefthy.cloud/openwrt/$resource.zip -O /tmp/$resource.zip && \
  unzip -d / /tmp/$resource.zip && \
  rm /tmp/$resource.zip
done

chmod +x /etc/init.d/sefthy-*

ln -sf /opt/sefthy-wrt-gui/uptimex /usr/sbin/uptimex
ln -sf /opt/sefthy-wrt-gui/speedtest /usr/sbin/speedtest
ln -sf /opt/sefthy-wrt-config/wg-quick /usr/sbin/wg-quick
chmod +x /usr/sbin/uptimex
chmod +x /usr/sbin/speedtest
chmod +x /usr/sbin/wg-quick

# Cron
mkdir -p /etc/cron.d
echo "* * * * * /opt/sefthy-wrt-config/config.sh" >> /etc/cron.d/sefthy
ln -s /etc/cron.d/sefthy /usr/lib/micron.d/sefthy
/etc/init.d/micrond enable
sleep 5 && /etc/init.d/micrond restart

# Fix sshx
mkdir -p /usr/local && ln -s /usr/sbin/ /usr/local/bin

# Custom Menu
cat <<EOF > /usr/share/luci/menu.d/luci-app-sefthy.json
{
  "admin/sefthy": {
    "title": "Sefthy GUI",
      "order": 60,
      "action": {
        "type": "template",
        "path": "sefthy/redirect"
      }
    }
}
EOF

mkdir -p /usr/lib/lua/luci/view/sefthy

cat <<EOF > /usr/lib/lua/luci/view/sefthy/redirect.htm
<%
local ip = luci.http.getenv("SERVER_NAME") or luci.http.getenv("HTTP_HOST") or "192.168.1.1"
ip = ip:match("([^:]+)")
local sefthy_url = "http://" .. ip .. ":81"

luci.http.redirect(sefthy_url)
%>
EOF

rm -rf /tmp/luci* && /etc/init.d/uhttpd restart && /etc/init.d/rpcd restart

# Start GUI
/etc/init.d/sefthy-wrt-gui enable
/etc/init.d/sefthy-wrt-gui start