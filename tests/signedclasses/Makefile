app.jar: App.java
	rm -rf classes
	mkdir classes
	javac -d classes App.java
	jar cf app.jar -C classes .

good.keystore:
	keytool -genkey -keystore ./good.keystore  -alias mykey -storepass abc123 -keypass abc123 -keyalg dsa -dname CN=jvmtest

bad.keystore:
	keytool -genkey -keystore ./bad.keystore  -alias notmykey -storepass abc123 -keypass abc123 -keyalg dsa -dname CN=jvmtest

app-signed.jar: good.keystore app.jar
	jarsigner -keystore ./good.keystore -storepass abc123 -keypass abc123 -signedjar app-signed.jar app.jar mykey

# Run with a policy that loads the good.keystore. 
good: app-signed.jar
	java -Djava.security.manager -Djava.security.policy=good.policy -Djava.security.debug=jar -cp app-signed.jar App

# Run with a policy that does NOT load the good.keystore. The 'grant signedBy "mykey" ...' block in bad.policy will be ignored as
# the "mykey" certificant cannot be found in bad.keystore.
bad: app-signed.jar bad.keystore
	java -Djava.security.manager -Djava.security.policy=bad.policy -Djava.security.debug=jar -cp app-signed.jar App

# Cannot run -Djava.security.debug=all with the "good" case -- it causes some sort of recursion and kills the VM
bad-debug:
	java -Djava.security.manager -Djava.security.policy=bad.policy -Djava.security.debug=jar -cp app-signed.jar App

clean:
	rm -rf copy classes *.jar *.class *~ *keystore


g: good
b: bad
c: clean
