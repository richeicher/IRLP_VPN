
#!/bin/sh

### BEGIN INIT INFO
# Provides:        firewall
# Required-Start:  $syslog
# Required-Stop:   $syslog
# Default-Start:   2 3 4 5
# Default-Stop:    0 1 6
# Short-Description: Start Firewall Services
### END INIT INFO

PATH=/sbin:/bin:/usr/sbin:/usr/bin

. /lib/lsb/init-functions

NAME=firewall
IPTABLES=/sbin/iptables

test -x $IPTABLES || exit 5

# Define The External Interface Name
EXTERNAL_INTERFACE="venet+"

# Define THe Internal (VPN) Interface Name
INTERNAL_INTERFACE="tun0"

# Define The Loopback Interface Name
LOOPBACK_INTERFACE="lo"

# Define TCP Ports which connections are permitted inbound
TCP_ACCEPT="22 1194 2222"
#
# vsftpd is set to use "63000:64000"

# Common TCP Ports
# 21/ftp
# 22/ssh
# 23/telnet
# 25/smtp
# 53/dns
# 80/http
# 110/pop3
# 143/imap
# 443/https
# 5666/nrpe (Nagios)

# Define UDP Ports which connections are permitted inbound
UDP_ACCEPT="53 1194"

# Common UDP Ports
# 53/dns
# 161/snmp

# Define ICMP Types/codes which are permitted inbound
ICMP_ACCEPT="3/0 3/4 3/10 11/0 11/1"
#ICMP_ACCEPT=""

# Common ICMP Types
# 3/0 = Port Unreachable
# 3/4 = Fragmentation needed
# 3/10 = Communication Administratively Prohibited
# 8/0 = Echo Request
# 11/0 = Time to Live exceeded in transit
# 11/1 = Fragment Reassembly Time Exceeded

# Broadcast Types to Block (broadcast, multicast, unicast)
#BCAST_BLOCK="broadcast multicast"
# Does not work on OpenVZ?
BCAST_BLOCK=""

# Trusted sources which will have NO filtering applied.
# Please add here with caution!
TRUSTED_SOURCE=""

#NRPE="0/0"

# Service specific ACLs
SSH_CLIENTS="0/0"
#RSYNC_CLIENTS="166.84.0.28"

IRLP=10.8.0.2
IRLPTCP="222 15425:15428"
IRLPUDP="2074:2094"

if [ -r /etc/default/$NAME ]; then
	. /etc/default/$NAME
fi

case $1 in
	start)
		log_daemon_msg "Starting Firewall Services" 
		#

		# First accept anything that is already in the state table
		$IPTABLES -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
		$IPTABLES -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

		# Set Default Policies to drop
		$IPTABLES -P INPUT DROP
		$IPTABLES -P OUTPUT DROP
		$IPTABLES -P FORWARD DROP
		#

		# Allow everything on loopback
		$IPTABLES -A INPUT -i $LOOPBACK_INTERFACE -j ACCEPT
		$IPTABLES -A OUTPUT -o $LOOPBACK_INTERFACE -j ACCEPT

		# Allow listed TCP services in
		if [ "${TCP_ACCEPT}" != "" ]
		then
		for tcp in ${TCP_ACCEPT}
		do
		$IPTABLES -A INPUT -i $EXTERNAL_INTERFACE -p tcp -s 0/0 --sport 1024:65535 -d 0/0 --dport $tcp -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
		$IPTABLES -A OUTPUT -o $EXTERNAL_INTERFACE -p tcp -s 0/0 --sport $tcp -d 0/0 --dport 1024:65535 -m state --state ESTABLISHED,RELATED -j ACCEPT
		done
		fi

                # Allow listed UDP services in
                if [ "${UDP_ACCEPT}" != "" ]
                then
                for udp in ${UDP_ACCEPT}
                do
                $IPTABLES -A INPUT -i $EXTERNAL_INTERFACE -p udp -s 0/0 --sport 1024:65535 -d 0/0 --dport $udp -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
                $IPTABLES -A OUTPUT -o $EXTERNAL_INTERFACE -p udp -s 0/0 --sport $udp -d 0/0 --dport 1024:65535 -m state --state ESTABLISHED,RELATED -j ACCEPT
		done
		fi

                # Allow listed ICMP Types/Codes in
		if [ "${ICMP_ACCEPT}" != "" ]
		then
		for icmp in ${ICMP_ACCEPT}
		do

		$IPTABLES -A INPUT -i $EXTERNAL_INTERFACE -p icmp -s 0/0 --icmp-type $icmp -d 0/0 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

		done
		fi

		# Block Broadcast, Multicast and Unicast traffic from being logged
		if [ "${BCAST_BLOCK}" != "" ]
		then
		for bcast in ${BCAST_BLOCK}
		do

		echo $IPTABLES -A INPUT -i $EXTERNAL_INTERFACE -m pkttype --pkt-type $bcast -j DROP	

		done
		fi


                # Allow listed sources in
                if [ "${TRUSTED_SOURCE}" != "" ]
                then
                for trusted in ${TRUSTED_SOURCE}
                do
                $IPTABLES -A INPUT -i $EXTERNAL_INTERFACE -s $trusted -d 0/0 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
                done
                fi
		#--------#
                # SSH/22 #
		#--------#
		if [ "${SSH_CLIENTS}" != "" ]
		then
		for ssh in ${SSH_CLIENTS}
		do
		$IPTABLES -A INPUT -i $EXTERNAL_INTERFACE -p tcp -s $ssh -d 0/0 --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
		done
		fi

		#-----------#
		# RSYNC/873 #
		#-----------#
		if [ "${RSYNC_CLIENTS}" != "" ]
		then
		for rsync in ${RSYNC_CLIENTS}
		do
		IPTABLES -A INPUT -i $EXTERNAL_INTERFACE -p tcp -s $rsync -d 0/0 --dport 873 -m state --state NEW,ESTABLISHED -j ACCEPT
		done
		fi


                if [ "${NRPE}" != "" ]
                then
                for nrpe in ${NRPE}
                do
                $IPTABLES -A INPUT -p tcp -i $EXTERNAL_INTERFACE -s $nrpe --sport 1024:65535 -d 0/0 --dport 5666 -m state --state NEW,ESTABLISHED -j ACCEPT
                $IPTABLES -A OUTPUT -p tcp -o $EXTERNAL_INTERFACE -s 0/0 --sport 5666 -d $nrpe --dport 1024:65535 -m state --state ESTABLISHED -j ACCEPT
                done
                fi

	        # Allow IRLP traffic
	        if [ "${IRLPTCP}" != "" ]
	        then
	        for irlptcp in ${IRLPTCP}
	        do
	        $IPTABLES -t nat -A PREROUTING -p tcp -i $EXTERNAL_INTERFACE -s 0/0 --sport 1024:65535 -d 0/0 --dport $irlptcp -j DNAT --to-dest $IRLP
	        $IPTABLES -A FORWARD -p tcp -i $EXTERNAL_INTERFACE -s 0/0 --sport 1024:65535 -o $INTERNAL_INTERFACE -d $IRLP --dport $irlptcp -m state --state NEW,ESTABLISHED -j ACCEPT
	        $IPTABLES -A FORWARD -p tcp -i $INTERNAL_INTERFACE -s $IRLP --sport $irlptcp -o $EXTERNAL_INTERFACE -d 0/0 --dport 1024:65535 -m state --state ESTABLISHED -j ACCEPT
	        $IPTABLES -t nat -A POSTROUTING -p tcp -o $EXTERNAL_INTERFACE -s $IRLP --sport $irlptcp -d 0/0 --dport 1024:65535 -j MASQUERADE
	        done
	        fi

	        if [ "${IRLPUDP}" != "" ]
	        then
	        for irlpudp in ${IRLPUDP}
	        do
	        $IPTABLES -t nat -A PREROUTING -p udp -i $EXTERNAL_INTERFACE -s 0/0 --sport 1024:65535 -d 0/0 --dport $irlpudp -j DNAT --to-dest $IRLP
	        $IPTABLES -A FORWARD -p udp -i $EXTERNAL_INTERFACE -s 0/0 --sport 1024:65535 -o $INTERNAL_INTERFACE -d $IRLP --dport $irlpudp -m state --state NEW,ESTABLISHED -j ACCEPT
	        $IPTABLES -A FORWARD -p udp -i $INTERNAL_INTERFACE -s $IRLP --sport $irlpudp -o $EXTERNAL_INTERFACE -d 0/0 --dport 1024:65535 -m state --state ESTABLISHED -j ACCEPT
	        $IPTABLES -t nat -A POSTROUTING -p udp -o $EXTERNAL_INTERFACE -s $IRLP --sport $irlpudp -d 0/0 --dport 1024:65535 -j MASQUERADE
	        done
	        fi

		# Allow all outbound from Internal Interface
		$IPTABLES -A FORWARD -i $INTERNAL_INTERFACE -o $EXTERNAL_INTERFACE -d 0/0 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
		$IPTABLES -A FORWARD -i $EXTERNAL_INTERFACE -s 0/0 -o $INTERNAL_INTERFACE -m state --state ESTABLISHED,RELATED -j ACCEPT
		$IPTABLES -t nat -A POSTROUTING -o $EXTERNAL_INTERFACE -m state --state NEW,ESTABLISHED,RELATED -j MASQUERADE

		# Permit all new and established traffic out
		$IPTABLES -A OUTPUT -o $EXTERNAL_INTERFACE -s 0/0 -d 0/0 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
		$IPTABLES -A INPUT -i $EXTERNAL_INTERFACE -s 0/0 -d 0/0 -m state --state ESTABLISHED,RELATED -j ACCEPT

		# Logging and dropping everything else
		# TCP
		$IPTABLES -A INPUT -i $EXTERNAL_INTERFACE -p tcp -j LOG --log-prefix "IPT TCP In: "
		$IPTABLES -A INPUT -i $EXTERNAL_INTERFACE -p tcp -j DROP
		# UDP
		$IPTABLES -A INPUT -i $EXTERNAL_INTERFACE -p udp -j LOG --log-prefix "IPT UDP In: "
		$IPTABLES -A INPUT -i $EXTERNAL_INTERFACE -p udp -j DROP
		# ICMP
		$IPTABLES -A INPUT -i $EXTERNAL_INTERFACE -p icmp -j LOG --log-prefix "IPT ICMP In: "
		$IPTABLES -A INPUT -i $EXTERNAL_INTERFACE -p icmp -j DROP
		# Everything else
		$IPTABLES -A INPUT -i $EXTERNAL_INTERFACE -j LOG --log-prefix "IPT Misc In: "
		$IPTABLES -A INPUT -i $EXTERNAL_INTERFACE -j DROP
		
		log_end_msg $?
  		;;
	stop)
		log_daemon_msg "Stopping Firewall Services"
		
		# Setting default policies to accept
		$IPTABLES -P INPUT ACCEPT
		$IPTABLES -P OUTPUT ACCEPT
		$IPTABLES -P FORWARD ACCEPT

		# Flush all rules
		$IPTABLES -F
		$IPTABLES -t nat -F

		log_end_msg $?
  		;;
	restart)
		$0 stop && $0 start
  		;;
	*)
		echo "Usage: $0 {start|stop|restart}"
		exit 2
		;;
esac

