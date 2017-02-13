# Perfect SPNEGO demo [简体中文](README.zh_CN.md)

<p align="center">
    <a href="http://perfect.org/get-involved.html" target="_blank">
        <img src="http://perfect.org/assets/github/perfect_github_2_0_0.jpg" alt="Get Involed with Perfect!" width="854" />
    </a>
</p>

<p align="center">
    <a href="https://github.com/PerfectlySoft/Perfect" target="_blank">
        <img src="http://www.perfect.org/github/Perfect_GH_button_1_Star.jpg" alt="Star Perfect On Github" />
    </a>  
    <a href="http://stackoverflow.com/questions/tagged/perfect" target="_blank">
        <img src="http://www.perfect.org/github/perfect_gh_button_2_SO.jpg" alt="Stack Overflow" />
    </a>  
    <a href="https://twitter.com/perfectlysoft" target="_blank">
        <img src="http://www.perfect.org/github/Perfect_GH_button_3_twit.jpg" alt="Follow Perfect on Twitter" />
    </a>  
    <a href="http://perfect.ly" target="_blank">
        <img src="http://www.perfect.org/github/Perfect_GH_button_4_slack.jpg" alt="Join the Perfect Slack" />
    </a>
</p>

<p align="center">
    <a href="https://developer.apple.com/swift/" target="_blank">
        <img src="https://img.shields.io/badge/Swift-3.0-orange.svg?style=flat" alt="Swift 3.0">
    </a>
    <a href="https://developer.apple.com/swift/" target="_blank">
        <img src="https://img.shields.io/badge/Platforms-OS%20X%20%7C%20Linux%20-lightgray.svg?style=flat" alt="Platforms OS X | Linux">
    </a>
    <a href="http://perfect.org/licensing.html" target="_blank">
        <img src="https://img.shields.io/badge/License-Apache-lightgrey.svg?style=flat" alt="License Apache">
    </a>
    <a href="http://twitter.com/PerfectlySoft" target="_blank">
        <img src="https://img.shields.io/badge/Twitter-@PerfectlySoft-blue.svg?style=flat" alt="PerfectlySoft Twitter">
    </a>
    <a href="http://perfect.ly" target="_blank">
        <img src="http://perfect.ly/badge.svg" alt="Slack Status">
    </a>
</p>

Perfect Empty Starter Project with SPNEGO feature

This example is based on [PerfectTemplate](https://github.com/PerfectlySoft/PerfectTemplate). If you are not familiar PerfectTemplate, please try it first.

## Building Notes

This project can be built with **Swift 3.0.2** toolchain on both Ubuntu and macOS.

### Xcode Build Note

If you would like to use Xcode to build this project, please make sure to pass proper linker flags to the Swift Package Manager:

```
$ swift package -Xlinker -framework -Xlinker GSS generate-xcodeproj
```

### Linux Build Note

A special library called libkrb5-dev is required to build this project:

```
$ sudo apt-get install libkrb5-dev
```

## KDC Configuration

Configure the application server's /etc/krb5.conf to your KDC. The following sample configuration shows how to connect your application server to realm `KRB5.CA` under control of a KDC named `nut.krb5.ca`:

```
[realms]
KRB5.CA = {
	kdc = nut.krb5.ca
	admin_server = nut.krb5.ca
}
[domain_realm]
.krb5.ca = KRB5.CA
krb5.ca = KRB5.CA
```

## Prepare Kerberos Keys for Server

Contact to your KDC administrator to assign a `keytab` file to your application server.

Take example, *SUPPOSE ALL HOSTS BELOW REGISTERED ON THE SAME DNS SERVER*:

- KDC server: nut.krb5.ca
- Application server: apple.krb5.ca
- Application server type: HTTP

In such a case, KDC administrator shall login on `nut.krb5.ca` then perform following operation:

```
kadmin.local: addprinc -randkey HTTP/apple.krb5.ca@KRB5.CA
kadmin.local: ktadd -k /tmp/krb5.keytab HTTP/apple.krb5.ca@KRB5.CA
```

Then please ship this krb5.keytab file securely and install on your application server `apple.krb5.ca` and move to folder `/etc`, then grant sufficient permissions to your swift application to access it.

## Building & Running

The following will clone and build an empty starter project with SPNEGO plugin and launch the server on port 8080.

```
git clone https://github.com/PerfectExamples/Perfect-SPNEGO-Demo.git
cd Perfect-SPNEGO-Demo
swift build
.build/debug/PerfectTemplate
```

You should see the following output:

```
[INFO] Starting HTTP server localhost on 0.0.0.0:8080
```

This means the servers are running and waiting for connections.

Now, you can check `http://apple.krb5.ca:8080` to see if it works.
If you are using SPNEGO compatible browser, such Safari, then a login dialog may pop up and ask for credentials.
Or alternatively, you can use a curl command to better understand what will happen:

```
$ kinit
$ curl -v --negotiate -u : http://apple.krb5.ca:8080
```

You may find that curl would return "unauthorized" unless providing `kinit` with correct user name / password.

### URL Note

To run this demo correctly, please use FQDN (fully qualified domain name) instead of `localhost` or ip address on both client and server.

## Go Through the SPNEGO plugin

The demo source added a few different lines to the PerfectTemplate to verify user identification.

Firstly, it initializes a SPNEGO object before accepting incoming HTTP requests.
Secondly, it sets the default response to `.unauthorized` and instruct the client to negotiate with the server by SPNEGO tokens.
If a valid negotiation based64 token was found on the request, the server would try to accept it and figure out who was trying to request the current resource by calling the only method of SPNEGO - ` let (username, reply_token) = try spnego.accept(base64Token: inputToken)`

If username is not nil, it means that the user is valid and you may validate its permission on the current resource link by verifying your own ACL (access control list), otherwise the request shall be rejected.

Please note that an reply token might also be generated and you should send this new token back as a fulfilled response.

```swift
import PerfectSPNEGO
import Darwin
// NOTE: Host Name Must Be FQDN and registered with a valid keytab from KDC.
let hostname = "apple.krb5.ca"

// a secured handler
func handler(data: [String:Any]) throws -> RequestHandler {
	return {
		request, response in

		// The spnego requests every secured responses MUST be unauthorized because it's session independent.
    response.status = .unauthorized

    // Client and Server must be synchronized, so return it with a GMT time.
    response.setHeader(.date, value: GMTNow())

    // Instruct the client to negotiate with server.
    response.setHeader(.wwwAuthenticate, value: "Negotiate")
    response.setHeader(.contentType, value: "text/html")

    // if the client has no valid kerberos ticket, reject it.
    guard let auth = request.header(.custom(name: "Authorization")) else {
      response.appendBody(string: "<html><H1>ACCESS DENIED</H1></html>\n")
      response.completed()
      return
    }//end auth

    // extract a spnego token from client
    let negotiate = "Negotiate "
    guard auth.hasPrefix(negotiate) else {
      response.appendBody(string: "<html><H1>INVALID TOKEN FORMAT</H1></html>\n")
      response.completed()
      return
    }//end auth.prefix

    // parse the token from the client request header
    let inputToken = String(auth.characters.dropFirst(negotiate.utf8.count))
    do {

      let spnego = try Spnego("HTTP@\(hostname)")

      // try to accept the token
      let (username, outputToken) = try spnego.accept(base64Token: inputToken)

      // check if the server has another token to reply to the client
      if let reply = outputToken {
        response.setHeader(.custom(name: "Authorization"), value:"Negotiate \(reply)")
      }//end if

      // check if authenticated successfully.
      if let user = username {

        // USER AUTHENTICATION SUCCESS.
        // *NOTE* on production servers, you may need an ACL list to check even the authenticated user
        // has the permission to this specific resource.
        response.status = .accepted


        // return the protected resource here.
        response.appendBody(string: "<html><title>Hello, world!</title><body>Welcome, \(user)</body></html>\n")


      }else {

        // this may happen by sort of DNS errors, i.e, client is using a nick name or ip other than a FQDN
        // (full qualified domain name) to access the server.
        response.appendBody(string: "<html><H1>GSS REQUEST TO CALL IT ONCE MORE</H1></html>\n")
      }//end if
    }catch (let err) {

      // access denied
      response.appendBody(string: "<html><H1>AUTHENTICATION FAILED: \(err)</H1></html>\n")
    }//end du

    // Ensure that response.completed() is called when your processing is done.
    response.completed()
	}
}

```


## Issues

We are transitioning to using JIRA for all bugs and support related issues, therefore the GitHub issues has been disabled.

If you find a mistake, bug, or any other helpful suggestion you'd like to make on the docs please head over to [http://jira.perfect.org:8080/servicedesk/customer/portal/1](http://jira.perfect.org:8080/servicedesk/customer/portal/1) and raise it.

A comprehensive list of open issues can be found at [http://jira.perfect.org:8080/projects/ISS/issues](http://jira.perfect.org:8080/projects/ISS/issues)



## Further Information
For more information on the Perfect project, please visit [perfect.org](http://perfect.org).
