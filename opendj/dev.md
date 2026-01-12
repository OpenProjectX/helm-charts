```shell

helm dependency update
helm template .  

helm install opendj ./ --namespace it

helm install opendj openprojectx/opendj --namespace it



helm upgrade opendj ./ --namespace it

helm uninstall opendj  --namespace it


kubectl apply -f /data/Git/openprojectx-helm-charts/opendj/debug.yaml

kubectl logs -n it job/opendj-bootstrap --timestamps

export LDAP_URI=ldaps://ldap.openprojectx.org:1636
export BASE_DN="dc=openprojectx,dc=org"
#export ADMIN_DN="cn=Directory Manager"        # OpenDJ
export  ADMIN_DN="cn=admin"  # OpenLDAP
export ADMIN_PW="REPLACE_IT"

ldapsearch -d 5 -H ldaps://ldap.openprojectx.org:1636  -D "cn=admin" -w REPLACE_IT -b "cn=schema" -s base + > schema.ldif

ldapsearch -H ldaps://ldap.openprojectx.org:1636 -x -D "cn=admin" -w REPLACE_IT -b "cn=schema" -s base -a always + "(objectClass=*)" "*"

ldapsearch -H ldaps://ldap.openprojectx.org:1636 -x -D "cn=admin" -w REPLACE_IT \
  -s base -b "" namingContexts
  
ldapsearch -H ldaps://ldap.openprojectx.org:1636 -x -D "cn=admin" -w REPLACE_IT \
  -b "dc=openprojectx,dc=org" -s base "(objectClass=*)" dn


ldapsearch -x \
  -H ldap://opendj-opendj:1389 \
  -D "$LDAP_BIND_DN" \
  -w "$LDAP_ADMIN_PASSWORD" \
  -b "" \
  -s base \
  namingContexts
  
################
#1.1 Check what suffixes (Base DNs) the server serves
ldapsearch -x -H $LDAP_URI \
  -s base -b "" namingContexts

#1.2 Verify the base entry exists
ldapsearch -x -H $LDAP_URI \
  -b "$BASE_DN" -s base "(objectClass=*)" dn
  
#  1.3 Who am I binding as?
ldapwhoami -x -H $LDAP_URI \
  -D "$ADMIN_DN" -w "$ADMIN_PW"  
  
#2.1 List all users
ldapsearch -x -H $LDAP_URI \
  -b "ou=people,$BASE_DN" "(objectClass=inetOrgPerson)" dn uid mail  
  
ldapsearch -x -H $LDAP_URI \
  -b "dc=openprojectx,dc=org" "(objectClass=inetOrgPerson)" dn uid mail    
  
#2.2 List all applications (service accounts)  
ldapsearch -x -H $LDAP_URI \
  -b "ou=apps,$BASE_DN" "(objectClass=account)" dn uid description

ldapsearch -x -H $LDAP_URI \
  -b "ou=apps,$BASE_DN" "(objectClass=account)" 
  
ldapsearch -x -H $LDAP_URI \
  -b "dc=openprojectx,dc=org" "(objectClass=*)"   dn uid mail  entryUUID     
  
#2.3 List all groups
ldapsearch -x -H $LDAP_URI \
  -b "ou=groups,$BASE_DN" "(objectClass=groupOfNames)" cn

ldapsearch -x -H $LDAP_URI \
  -b "ou=groups,$BASE_DN" "(objectClass=groupOfNames)"

#2.4 See who is in a group
ldapsearch -x -H $LDAP_URI \
  -b "cn=it,ou=groups,$BASE_DN" member

#2.5 See which groups a user belongs to (group-side)
ldapsearch -x -H $LDAP_URI \
  -b "ou=groups,$BASE_DN" \
  "(member=uid=alice,ou=people,$BASE_DN)" cn
  
#  3.1 Add a user
ldapadd -x -H $LDAP_URI \
  -D "$ADMIN_DN" -w "$ADMIN_PW" <<EOF
dn: uid=carol,ou=people,$BASE_DN
objectClass: inetOrgPerson
objectClass: posixAccount
cn: Carol Wang
sn: Wang
uid: carol
mail: carol@openprojectx.org
uidNumber: 10003
gidNumber: 10000
homeDirectory: /home/carol
loginShell: /bin/bash
userPassword: REPLACE_ME
EOF

ldapadd -x -H $LDAP_URI \
  -D "$ADMIN_DN" -w "$ADMIN_PW" <<EOF
dn: uid=admin,ou=people,dc=openprojectx,dc=org
objectClass: top
objectClass: inetOrgPerson
objectClass: posixAccount
cn: Admin
sn: X
uid: admin
mail: admin@openprojectx.org
uidNumber: 10001
gidNumber: 10000
homeDirectory: /home/admin
loginShell: /bin/bash
userPassword: 114514
EOF

#3.2 Disable a user (soft lock, best practice)
ldapmodify -x -H $LDAP_URI \
  -D "$ADMIN_DN" -w "$ADMIN_PW" <<EOF
dn: uid=carol,ou=people,$BASE_DN
changetype: modify
replace: loginShell
loginShell: /sbin/nologin
EOF

#3.3 Reset a password
ldappasswd -x -H $LDAP_URI \
  -D "$ADMIN_DN" -w "$ADMIN_PW" \
  "uid=admin,ou=people,$BASE_DN"

#3.4 Delete a user
ldapdelete -x -H $LDAP_URI \
  -D "$ADMIN_DN" -w "$ADMIN_PW" \
  "uid=carol,ou=people,$BASE_DN"

#4.1 Create a group
ldapadd -x -H $LDAP_URI \
  -D "$ADMIN_DN" -w "$ADMIN_PW" <<EOF
dn: cn=finance,ou=groups,$BASE_DN
objectClass: groupOfNames
cn: finance
member: uid=alice,ou=people,$BASE_DN
EOF

ldapadd -x -H $LDAP_URI \
  -D "$ADMIN_DN" -w "$ADMIN_PW" <<EOF
dn: cn=admin,ou=groups,dc=openprojectx,dc=org
objectClass: groupOfNames
cn: admin
member: uid=admin,ou=people,dc=openprojectx,dc=org
EOF

#4.2 Add a user to a group
ldapmodify -x -H $LDAP_URI \
  -D "$ADMIN_DN" -w "$ADMIN_PW" <<EOF
dn: cn=it,ou=groups,$BASE_DN
changetype: modify
add: member
member: uid=carol,ou=people,$BASE_DN
EOF

#4.3 Remove a user from a group
ldapmodify -x -H $LDAP_URI \
  -D "$ADMIN_DN" -w "$ADMIN_PW" <<EOF
dn: cn=it,ou=groups,$BASE_DN
changetype: modify
delete: member
member: uid=carol,ou=people,$BASE_DN
EOF

#4.4 Rename a group (safe method)
ldapmodrdn -x -H $LDAP_URI \
  -D "$ADMIN_DN" -w "$ADMIN_PW" \
  "cn=it,ou=groups,$BASE_DN" "cn=engineering"

#5.1 Create an app account
ldapadd -x -H $LDAP_URI \
  -D "$ADMIN_DN" -w "$ADMIN_PW" <<EOF
dn: uid=datahub-ingestor,ou=apps,$BASE_DN
objectClass: account
objectClass: simpleSecurityObject
uid: datahub-ingestor
description: DataHub metadata ingestion service
userPassword: REPLACE_ME
EOF

#5.2 Rotate app credentials
ldappasswd -x -H $LDAP_URI \
  -D "$ADMIN_DN" -w "$ADMIN_PW" \
  "uid=datahub-ingestor,ou=apps,$BASE_DN"

#5.3 Test app bind (very important)
ldapwhoami -x -H $LDAP_URI \
  -D "uid=datahub-ingestor,ou=apps,$BASE_DN" \
  -w 'GET_FROM_RESET'

#6.1 Can a user read groups?
ldapsearch -x -H $LDAP_URI \
  -D "uid=alice,ou=people,$BASE_DN" -w 'rnq72wqi' \
  -b "ou=groups,$BASE_DN" "(objectClass=groupOfNames)" cn

7.1 Export everything (LDIF backup)
ldapsearch -x -H $LDAP_URI \
  -D "$ADMIN_DN" -w "$ADMIN_PW" \
  -b "$BASE_DN" "(objectClass=*)" > backup.ldif

#7.2 Restore
ldapadd -x -H $LDAP_URI \
  -D "$ADMIN_DN" -w "$ADMIN_PW" \
  -f backup.ldif


```