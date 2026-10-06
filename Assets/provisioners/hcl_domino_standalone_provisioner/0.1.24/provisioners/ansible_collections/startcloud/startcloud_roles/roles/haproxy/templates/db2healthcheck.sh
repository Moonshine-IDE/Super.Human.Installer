#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin:/etc/haproxy
PEERIP=$2
VIRTIP=$5
REALIP=$3
cd /etc/haproxy
#### Retrive Variables
### Get Node State --  HAProxy will run this script for both Servers so $REALIP will change
ssh db2inst1@$REALIP 'db2pd -alldbs -hadr' >> $REALIP.RESULTS.log

## Connect to Database -- Future Test
#ssh db2inst1@$REALIP 'db2 connect to travhth3' > $REALIP-DATA
###/

#### Filter Results
## Check if the Node is set as PRIMARY/STANDY
ROLE=$(cat $REALIP.RESULTS.log | grep -w 'HADR_ROLE'| grep -o 'PRIMARY\|STANDBY')

## Check if the HADR Statee is CONNECTED/DISCONNECTED -- Healthy/Broken Replication respectivley 
STATE=$(cat $REALIP.RESULTS.log | grep -w 'HADR_CONNECT_STATUS' | grep -o 'CONNECTED\|DISCONNECTED')
HEALTH=$(cat HEALTH.log) ### Intitialize Health as Stable during setup, not here.

## Clear away temp file for next session
rm -rf $REALIP.RESULTS.log       
###/

#### HADR Failover logic
## If the Node the check is being ran on is Primary and State is Connected Exit Cleanly
if [[ "$ROLE" = "PRIMARY" && "$STATE" = "CONNECTED" ]]; then
    HEALTH=$(cat HEALTH.log)
    echo "$REALIP is PRIMARY and STANDBY is reporting as CONNECTED and the cluster is: $HEALTH" >> $REALIP.log
    if [[ "$HEALTH" = "FAILEDOVER" ]]; then
      echo "STABLE" > HEALTH.log
    fi
    exit $?
fi

## if the Node the check is being ran is Primary and HADR State is Disconnected Exit Cleanly as Primary Node is up, silently log error that failover server has failed
if [[  "$ROLE" = "PRIMARY" && "$STATE" = "DISCONNECTED" ]]; then
    echo "$REALIP is PRIMARY and STANDBY is reporting as DISCONNECTED!!! and the cluster is: $HEALTH" >> $REALIP.log
    ## No logic needed here to bring up the Node with the Catch at the Bottom
      echo "DISCONNECTED" > HEALTH.log
    exit $?
fi

## if the Node this check is being ran is on STANDBY and HADR State is CONNECTED Exit Cleanly as Primary Node is Up and Connected
if [[  "$ROLE" = "STANDBY" && "$STATE" = "CONNECTED" ]]; then
    echo "$REALIP is STANDBY and PRIMARY is reporting as CONNECTED, and the cluster is: $HEALTH" >> $REALIP.log
    
    # Before we move on, since we prefer DB2 as Master, Let's Check if we are in a Failedover State and if we are let's move back -- Needs Error Code
    if [[ "$HEALTH" = "STABLE" && $REALIP = "192.168.2.87"  ]]; then
      echo "Cluster Running in FAILEDOVER STATE!!" >> $REALIP.log
      TAKEOVER=$(ssh db2inst1@$REALIP "db2 takeover hadr on db travhth3") 
      echo "$TAKEOVER" >> $REALIP.log
      echo "Successful Resumption!" >> $REALIP.log
      echo "STABLE" > HEALTH.log
      exit $?
    elif [[ "$HEALTH" = "DISCONNECTED" ]]; then
      echo "STABLE" > HEALTH.log
    fi
    exit $?
fi

## if the Node this check is being ran on is STANDBY and HADR State is DISCONNECTED, attempt to takeover this database as PRIMARY
if [[  "$ROLE" = "STANDBY" && "$STATE" = "DISCONNECTED" ]]; then
     echo "Turning on failover! $REALIP is STANDBY and PRIMARY is reporting as DISCONNECTED, and the cluster is: $HEALTH" >> $REALIP.log
     TAKEOVER=$(ssh db2inst1@$REALIP "db2 takeover hadr on db travhth3 by force") ## Will need to change logic
     if [[$TAKEOVER && "$HEALTH" = "FAILEDOVER" ]]; then
      echo Successful Takeover! >> $REALIP.log
      echo "FAILEDOVER" > HEALTH.log
      exit $?
     fi
fi
###/

#### DB2 Disconnected from HADR or Rebooted

## If This node is not CONNECTED or DISCONNECTED to HADR, try to start up DB2 and connect it
if [[ "$STATE" = "DISCONNECTED" || "$STATE" = "CONNECTED" ]]; then
 exit 0
else
 echo "No State found or HADR not started!!" >> $REALIP.log
 HEALTH=$(cat HEALTH.log)
 ## If the Cluster Health is FAILEDOVER
 if [[ "$HEALTH" = "FAILEDOVER" || "$HEALTH" = "DISCONNECTED"  ]]; then

    echo "Cluster Running in FAILEDOVER STATE!!" >> $REALIP.log

    ## Tell Node to try to Start DB2
#    ssh db2inst1@$REALIP "db2start" > $REALIP.Start.log
#    START=$(cat $REALIP.Start.log)
#    echo "$START" >> $REALIP.log

    ##  If Succesfuly, Move one, Else Email and Check Again report Node as Down    
    ##  Tell  Node to Start HADR on the database as STANDBY
    ssh db2inst1@$REALIP "db2 start hadr on db travhth3 as STANDBY"  > $REALIP.HADR.log
    
    HADR=$(cat $REALIP.HADR.log)
    echo "$HADR" >> $REALIP.log
    exit $?
 fi
fi
