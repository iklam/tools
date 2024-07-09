This sample shows:

- Class signing seems to depend only on the contents of the JAR file. The certificate used
  to sign the JAR file is stored as part of the JAR file. Class signing simply
  verifies that the .class files are indeed signed by this provided certificate.

- The SecurityManager's policy contains entries like this:

```
grant signedBy "mykey" {
    permission java.lang.RuntimePermission "setIO";
    permission java.lang.RuntimePermission "getProtectionDomain";
};
```

- When loading the policy file, if no certificates of "mykey" can be found in the current keystore,
  (or, ... if the certificate in the JAR file claims to be "mykey", but this certificate
   cannot be validated with the current keystore), then the above policy entry will simply be ignored.

- As a result, in the `make bad` test run, the following operaton will fail because there are
  no permissions granted for "setID", regardless of what certificate was used to sign the `App` class.

  AccessController.checkPermission(new RuntimePermission("setIO"));
  
  