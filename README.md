# cics-java-liberty-app-deployment

This repository provides a sample showing how to start a Liberty JVM server with its endpoint disabled and using a CICS policy to automatically resume the endpoint once the Java EE application has been installed.

The sample only demonstrates the capability for one application defined by a CICS bundle and only operates on one HTTP endpoint listener. However, a more realistic environment would have multiple applications in multiple bundles, installed in the same Liberty JVM server; it may also have multiple HTTP endpoints. This sample provides a good starting point to understand how the setup is done, and it can then be extended to support more complex scenarios.

The automated process shown in this sample can be useful when starting CICS regions. Once a CICS Liberty JVM server is enabled and ready, it will start to receive HTTP traffic even before Java EE applications are installed. In this period of time - after the Liberty server is ready and before the applications are installed - the Liberty server will return requests with an HTTP status code ***404 NOT FOUND***. To avoid such a situation, the Liberty JVM server can be started with its HTTP endpoint defined but `disabled`. This HTTP endpoint can then be resumed at a more appropriate time, for example when the bundle containing the application is enabled.

This sample is used with a Liberty JVM server and a web application installed with a CICS bundle. In order to distinguish the different bundles, let's refer to this bundle as the web application bundle.

This sample provides:
  * **a policy with a system rule** - the rule is triggered when the specified web application bundle ***enable status*** changes from `ANYTHING` to `ENABLED`, and the associated action is to produce an event
  * **an event processing adapter** - the event produced by the rule is processed by this adapter, it starts the transaction ***WLPC***
  * **a transaction WLPC** - this transaction is started from the event processing adatper (or through a 3270 terminal), it runs the COBOL program ***WLPCTRLW***
  * **a COBOL program WLPCTRLW** - this program is called by the event processing adapter, it links to the Java program ***WLPCTRL*** running in the Liberty JVM server
  * **a Java program WLPCTRL**  - this program calls the Liberty server's `ServerEndpointControl MBean` to ***pause*** or ***resume*** the HTTP endpoint listener

## Use case

A more detailed use case will be described in an upcoming blog post on [CICSDev](https://developer.ibm.com/cics/category/java/liberty/).

## Requirements

* CICS TS V5.5

  An enhancement was made in [CICS TS V5.5](https://www.ibm.com/support/knowledgecenter/en/SSGMCP_5.5.0/whats-new/intro.html#intro__Liberty) so the CICS bundle status now reflects the Liberty application status. This means that a CICS bundle that contains Java EE applications will only reach the `ENABLED` status when all the Java EE applications in the bundle are successfully installed in their Liberty JVM server. Once the bundle is enabled, the Java EE application context root is guaranteed to be available.

* CICS Explorer V5.4.X or later

  An enhancement was made in [CICS TS V5.4](https://www.ibm.com/support/knowledgecenter/SSGMCP_5.4.0/whats-new/intro.html#intro__policy-system-rules) and CICS Explorer V5.4 to provide a policy system rule for the CICS bundle enable status.

* A Liberty JVM server installed in CICS

* A web application bundle

  Any web application bundle would work. For instance, one of the following bundles can be used:
  * CICS Hello World - available in CICS Explorer, by creating a new project `Examples > CICS Examples > Java EE and Liberty`
  * <a href="https://github.com/cicsdev/cics-java-liberty-restapp" target="_blank">RESTAPP</a>

## Limitations

This sample only shows how to resume the Liberty JVM server HTTP endpoint when one specific web application bundle is `ENABLED`.
It also only targets one HTTP endpoint.

## Configuration

This sample uses three resource groups:
1. `WLPCGRP` - for the CICS bundle containing the policy, EP adapter, WLPC transaction and WLPCTRLW program.
2. `WLPINFRA` - for the Liberty JVM server
3. `WLPAPP` - for Java EE web applications installed via a bundle

***It is important that when added to a group list, these groups are added in the same order as listed above.***
The reason is that if the web application bundle is enabled before the policy is installed, then the policy system rule won't catch the change to enabled state.
This sample only provides the resources for the `WLPCGRP` group; it is assumed that a Liberty JVM server and a "test" web application bundle have been defined and installed prior to running this sample.
An existing group that already defines a Liberty JVM server can be used instead of `WLPINFRA`, which would define a new Liberty JVM server. This is also applicable for `WLPAPP`, an existing group with a web application bundle can be used instead.

### Customize the provided sample

1. Download the sample as a [ZIP](/archive/master.zip) or by cloning this repository
2. Import the two Eclipse [projects](projects) into CICS Explorer
3. In the `com.ibm.cicsdev.jmx.httpendpoint.controller` web project, fix the Build Path if some libraries cannot be resolved. The Build Path needs to contain the following libraries: Java 8, CICS TS 5.5 with Java EE and Liberty, and the JAR file provided in *WebContent/WEB-INF/lib*
4. In the `com.ibm.cicsdev.jmx.wlpolicy.cicsbundle` bundle project, open the `resume_liberty_httpendpont.policy` policy
   1. Modify the bundle name in the `on_bundle_enabled` rule to match the chosen web application bundle whose status is to be monitored by the policy
   2. Modify the static data in the rule action, if the HTTP endpoint ID does not match the default name of defaultHttpEndpoint used by the Liberty server
   Notice that the action in the rule, sets two static items: the first for the operation (RESUME or PAUSE, case-sensitive) and the second the Liberty server's HTTP endpoint ID. These items need to be specified in this order
5. In the `com.ibm.cicsdev.jmx.wlpolicy.cicsbundle`, open the warbundle file and modify the *jvmserver* value if it does not match the name of the JVM server
6. Deploy the `com.ibm.cicsdev.jmx.wlpolicy.cicsbunde` bundle to the z/OS Unix filesystem


### Compile the COBOL program

1. Upload the [`WLPCTRLW`](src/COBOL/WLPCTRLW.cbl) program to z/OS
2. Compile the program and put the load module into a CICS user load module library
This program is defined in the `com.ibm.cicsdev.jmx.wlpolicy.cicsbunde` bundle

### Define CICS resources

In the CICS region:
1. Define the `WLPOLICY` bundle in the `WLPCGRP` group, pointing to `com.ibm.cicsdev.jmx.wlpolicy.cicsbundle_1.0.0`. A [CSD extract](etc/DFHCSD.txt) is provided and can be used to define the CICS bundle, before using it the **BUNDLEDIR** attribute needs to be updated
2. Define the web application bundle in `WLPAPP`, if necessary
3. Add the 3 groups in a list in the proper order.  This list needs to be referenced by the GRPLIST SIT parameter

### Disable the Liberty JVM server HTTP endpoint

1. Go to the Liberty JVM server configuration folder
2. Edit the `server.xml` file to add the necessary features and `*enabled="false"*` to the httpEndpoint tag
```xml
<featureManager>
   <feature>cicsts:link-1.0</feature>
</featureManager>

<httpEndpoint id="defaultHttpEndpoint" enabled="false" host="*" httpPort="9080" httpsPort="9443"/>
```

### Restart the CICS region

In the CICS MSGUSR log, a message is printed when the WLPC transaction is started:
```
WLPCTRLW  04/12/2019 07:39:29 BEGIN RUNNING WLPCTRLW
```

When the CICS region is started, the event processing adapter may be called before the `CICSMessageListenerImpl MBean` is ready thus a link to Liberty will fail. So the `WLPCTRLW` COBOL program tries to link multiple times before giving up. The number of tries and the delay between each try can be changed in the COBOL program, so that it is more suited to the environment.

The following error message is printed in MSGUSR log when the listener is not available:
```
DFHSJ1006 E 04/12/2019 07:39:29 CICSMOBT STC An attempt to attach to JVMSERVER DFHWLP has failed because the Liberty link request
           listener is not available.                                                                                            
```

Upon success, the following message will be printed in the MSGUSR log:
```
WLPCTRLW  04/12/2019 07:40:00 LIBERTY HTTPENDPOINT HAS BEEN RESUMED
```
And the following message will be printed in the Liberty server messages.log:
```
I CWWKE0939I: A resume request completed.                                                        
O Thread(8178) 04/12/19 07:55:37:217 ServerEndpointControl MBean has resumed: defaultHttpEndpoint
```

## Other usage

The sample also defines the `WLPC` transaction, which can be used to manually (through a terminal) resume or pause the Liberty HTTP endpoint.
The syntax is:
<pre>
WLPC <i>operation</i> <i>httpEndpointId</i>
</pre>
where:
  * operation is ***mandatory***, and should either be *RESUME* or *PAUSE* (case-sensitive)
  * httpEndpointId is ***optional***, it is the ID (case-sensitive) of the httpEnpoint on which the action is performed. If not defined, the default value `defaultHttpEndpoint` is used

When used through a 3270 terminal, all messages are directly returned to the user and not written to MSGUSR.

## Troubleshooting

If the Liberty JVM server HTTP endpoint wasn't properly resumed:
1. Have a look at the CICS log to see if there are any relevent error messages
2. Check that all the resources have been properly installed and enabled
3. Try to start the transaction manually with *WLPC RESUME*

There are two main reasons for the following error message to appear in the CICS log:

```
WLPCTRLW  04/11/2019 15:20:07 ERROR LINKING TO WLPCTRL - RESP:00000027 RESP2:00000003
```

1. The WLPCTRL program is not available, in this case verify the installation process
2. The Liberty JVM server did not start the CICSMessageListener soon enough. Try allocating more threads to the JVM server, or modify the number of tries and the delay in the WLPCTRLW COBOL program

## License
This project is licensed under [Eclipse Public License Version 2.0](LICENSE).
