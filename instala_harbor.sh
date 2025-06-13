#!/bin/bash

### Crea los certificados SSL e instala Docker y Harbor.

export Password='nutanix/4u'
export Domain=`cat /etc/resolv.conf |grep search | awk '{print $2}'`
export HostName=`hostname`
#export IP4=`hostname -I`
export IP4=`ip a |grep -A1 eth0 |grep inet |awk '{print $2}'| awk -F '/' '{print $1}'`
export FQDN=$HostName.$Domain

export PAIS=CL                          # 2 letras, ejemplo CL (Chile)
export StateName=RM                     # Estado
export CityName=Santiago                # Ciudad
export CompanyName=Nutanix              # Empresa
export CompanySectionName=Sistemas      # Departamento
#export CommonNameOrHostname=*.$Domain   # Nombre servidor o dominio
export CommonNameOrHostname=$Domain   # Nombre servidor o dominio

mkdir -p CA && cd CA

# Crea rootCA.key y rootCA.crt con el nombre del servidor

openssl req -x509 -sha256 -days 1825 -newkey rsa:2048 -keyout rootCA.key -out rootCA.crt --passout pass:'$Password' -subj "/C=${PAIS}/ST=$StateName/L=$CityName/O=$CompanyName/OU=$CompanySectionName/CN=$HostName"

# Crea la key del dominio

openssl genrsa -out $Domain.key 2048

# Crea un Certificate Signing Request (CSR)

openssl req -key $Domain.key -new -out $Domain.csr -subj "/C=${PAIS}/ST=$StateName/L=$CityName/O=$CompanyName/OU=$CompanySectionName/CN=$CommonNameOrHostname"

# Crea el archivo san.cnf

touch san.cnf
echo "[req]" >> san.cnf
echo "distinguished_name = req_distinguished_name" >> san.cnf
echo "req_extensions = v3_req" >> san.cnf
echo "" >> san.cnf
echo "[req_distinguished_name]" >> san.cnf
echo "countryName                =" $PAIS  >> san.cnf
echo "stateOrProvinceName        =" $StateName >> san.cnf
echo "localityName               =" $CityName >> san.cnf
echo "organizationName           =" $CompanyName >> san.cnf
echo "commonName                 =" $CommonNameOrHostname >> san.cnf
echo "" >> san.cnf
echo "[v3_req]" >> san.cnf
echo "basicConstraints = CA:FALSE" >> san.cnf
echo "keyUsage = nonRepudiation, digitalSignature, keyEncipherment" >> san.cnf
echo "subjectAltName = @alt_names" >> san.cnf
echo "" >> san.cnf
echo "[alt_names]" >> san.cnf
echo "DNS.0 =" $FQDN >> san.cnf
echo "DNS.1 =" $CommonNameOrHostname >> san.cnf
echo "IP.0 =" $IP4 >> san.cnf


# Crea el certificado con el rootCA

openssl x509 -req -CA rootCA.crt -CAkey rootCA.key -in $Domain.csr -out $Domain.crt -days 365 -CAcreateserial -extfile san.cnf --passin pass:'$Password'

# Convert yourdomain.com.crt to yourdomain.com.cert, for use by Docker.
# The Docker daemon interprets .crt files as CA certificates and .cert files as client certificates.

openssl x509 -inform PEM -in $Domain.crt -out $Domain.cert


# Ver el certificado:

openssl x509 -text -noout -in $Domain.crt

cd ..


## Estructúra de directorio de certificados en Docker:

# /etc/docker/certs.d/
#     └── yourdomain.com:port
#        ├── yourdomain.com.cert  <-- Server certificate signed by CA
#        ├── yourdomain.com.key   <-- Server key signed by CA
#        └── ca.crt               <-- Certificate authority that signed the registry certificate


## Estructúra de directorio de certificados en Harbor:

# /data/cert
#        ├── yourdomain.com.crt
#        └── yourdomain.com.key

####### Ahora a instalar docker:

# Instalamos los certificados SSL recién creados

sudo mkdir -p /etc/docker/certs.d/$Domain

sudo cp CA/rootCA.crt /etc/docker/certs.d/$Domain
sudo cp CA/$Domain.cert /etc/docker/certs.d/$Domain
sudo cp CA/$Domain.key  /etc/docker/certs.d/$Domain

### Se debe instalar (o reiniciar si es que está instalado) docker:

touch daemon.json
echo "{" >> daemon.json
echo "    \"insecure-registries\": [\"$FQDN\"]" >> daemon.json
echo "}" >> daemon.json

sudo mv daemon.json /etc/docker/daemon.json

sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
sudo dnf -y install docker-ce docker-ce-cli containerd.io
sudo systemctl --now enable docker
sudo usermod -aG docker nutanix
sudo usermod -aG docker ${USER}

## Finalmente a instalar harbor:

sudo mkdir -p /data/cert

sudo cp CA/$Domain.cert /data/cert
sudo cp CA/$Domain.key  /data/cert

## Si es necesario bajar harbor:

curl -LO https://github.com/goharbor/harbor/releases/download/v2.13.1/harbor-offline-installer-v2.13.1.tgz
tar zxvf harbor-offline-installer-v2.13.1.tgz
cd harbor

# En el archivo harbor.yml se deben modificar las siguientes líneas, que deben verse como sigue:

#####################################
# hostname: registry.ntnxlab.local
#
#  certificate: /etc/docker/certs.d/ntnxlab.local/ntnxlab.local.cert
#  private_key: /etc/docker/certs.d/ntnxlab.local/ntnxlab.local.key
#####################################
# Comandos para hacerlo por script:

#mv harbor.yml.tmpl harbor.yml
cp harbor.yml.tmpl harbor.yml

sed -i 's/reg.mydomain.com/'$FQDN'/' harbor.yml
sed -i 's/certificate: \/your\/certificate\/path/certificate: \/etc\/docker\/certs.d\/'$Domain'\/'$Domain'.cert/' harbor.yml
sed -i 's/private_key: \/your\/private\/key\/path/private_key: \/etc\/docker\/certs.d\/'$Domain'\/'$Domain'.key/' harbor.yml

####  Ahora se puede instalar Harbor

sudo ./install.sh

cd ..
