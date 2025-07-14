# https://spring.io/guides/gs/spring-boot
# https://www.thomasvitale.com/https-spring-boot-ssl-certificate/

SRC = $(wildcard ./gs-spring-boot/complete/src/main/java/com/example/springboot/*.java) \
      $(wildcard ./gs-spring-boot/complete/src/main/resources/*)

ifneq ($(MAVEN_HTTP_PROXY_HOST),)
  MVN_OPTS=-Dhttp.proxyHost=${MAVEN_HTTP_PROXY_HOST} -Dhttp.proxyPort=${MAVEN_HTTP_PROXY_PORT} \
    -Dhttps.proxyHost=${MAVEN_HTTPS_PROXY_HOST} -Dhttps.proxyPort=${MAVEN_HTTPS_PROXY_PORT}
endif

app: ${SRC}
	cd gs-spring-boot/complete && JAVA_HOME=${GOODJAVAHOME} mvn ${MVN_OPTS} -Dmaven.test.skip=true package

TOKEN = -Dhttpft.token=${HTTPFT_TOKEN}

# Run with HTTPS (default)
run:
	${GOODJAVAHOME}/bin/java \
	    -Dspring.output.ansi.enabled=NEVER \
	    -Dserver.port=8443 \
	    -Dserver.address=0.0.0.0 \
	    -Dserver.ssl.key-store=file:springboot.p12 \
	    -Dserver.ssl.key-store-password=password \
	    -Dserver.ssl.key-store-type=pkcs12 \
	    -Dserver.ssl.key-alias=springboot \
	    -Dserver.ssl.key-password=password \
	    ${TOKEN} \
	    -jar ./gs-spring-boot/complete/target/spring-boot-complete-0.0.1-SNAPSHOT.jar

# Run with HTTP (for testing)
run0:
	${GOODJAVAHOME}/bin/java \
	    -Dspring.output.ansi.enabled=NEVER \
	    -Dserver.port=8443 \
	    -Dserver.address=0.0.0.0 \
	    ${TOKEN} \
	    -jar ./gs-spring-boot/complete/target/spring-boot-complete-0.0.1-SNAPSHOT.jar

# This is the self-signed key for testing
testkey:
	rm -f springboot.p12 
	keytool -genkeypair -alias springboot -keyalg RSA -keysize 4096 -storetype PKCS12 -keystore springboot.p12 -validity 3650 -storepass password

# Import cert/key for real HTTPFT_CERT/HTTPFT_KEY should point to the files given by your SSL certificate provider
key:
	@if ! test -f "${HTTPFT_CERT}"; then echo invalid HTTPFT_CERT; exit 1; fi
	@if ! test -f "${HTTPFT_KEY}"; then echo invalid HTTPFT_KEY; exit 1; fi
	rm -f springboot.p12
	openssl pkcs12 -export -name springboot -in ${HTTPFT_CERT} -inkey ${HTTPFT_KEY}.pem -out springboot.p12 -password pass:password

# I have version 7d77ad35767ff76f0a8f670a2ecd532083917dcc
___git:
	rm -rf gs-spring-boot
	git clone https://github.com/spring-guides/gs-spring-boot.git

# No need for this ...
# as suggested by https://stackoverflow.com/questions/17695297/importing-the-private-key-public-certificate-pair-in-the-java-keystore
#	keytool -importkeystore -destkeystore springboot.p12 -srckeystore keystore.p12 -srcstoretype pkcs12 \
#	    -alias springboot -storepass password

clean:
	rm -rf gs-spring-boot/complete/target springboot.p12


up:
	${GOODJAVAHOME}/bin/java ${TOKEN} -cp ./gs-spring-boot/complete/target/classes com.example.springboot.CommandLine \
		up ${HTTPFT_SERVER} $(shell pwd)/../.git /tmp/testdiffup/.git

down:
	${GOODJAVAHOME}/bin/java ${TOKEN} -cp ./gs-spring-boot/complete/target/classes com.example.springboot.CommandLine \
		down ${HTTPFT_SERVER} $(shell pwd)/../.git /tmp/testdiffup/.git

