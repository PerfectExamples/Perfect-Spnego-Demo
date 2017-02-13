//
//  main.swift
//  Perfect Spnego Demo
//
//  Created by Rockford Wei on 2/13/17.
//	Copyright (C) 2017 PerfectlySoft, Inc.
//
//===----------------------------------------------------------------------===//
//
// This source file is part of the Perfect.org open source project
//
// Copyright (c) 2015 - 2016 PerfectlySoft Inc. and the Perfect project authors
// Licensed under Apache License v2.0
//
// See http://perfect.org/licensing.html for license information
//
//===----------------------------------------------------------------------===//
//

import PerfectLib
import PerfectHTTP
import PerfectHTTPServer
import PerfectSPNEGO

// NOTE: Must Be FQDN and registered with a valid keytab from KDC.
#if os(Linux)
import LinuxBridge
let hostname = "nut.krb5.ca"
#else
import Darwin
let hostname = "apple.krb5.ca"
#endif

let port = 8080

Spnego.debug = true

func GMTNow() -> String {
  var now = time(nil)
  let gmt = gmtime(&now)
  let asc = asctime(gmt)
  let str = String(String(cString: asc!).characters.filter { $0 != "\n" && $0 != "\r" }) + " GMT"
  return str
}

// An example request handler.
// This 'handler' function can be referenced directly in the configuration below.
func handler(data: [String:Any]) throws -> RequestHandler {
	return {
		request, response in

		// The spnego requests every secured responses MUST be unauthorized because it's session independent.
    response.status = .unauthorized
    response.setHeader(.date, value: GMTNow())
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

        // *NOTE* on production servers, you may need an ACL list to check even the authenticated user
        // has the permission to this specific resource.
        response.status = .accepted
        response.appendBody(string: "<html><title>Hello, world!</title><body>Welcome, \(user)</body></html>\n")
      }else {

        // this may happen by sort of DNS errors, i.e, client is using a nick name or ip other than a FQDN 
        // (full qualified domain name) to access the server.
        response.appendBody(string: "<html><H1>GSS REQUEST TO CALL IT ONCE MORE</H1></html>\n")
      }//end if
      // Ensure that response.completed() is called when your processing is done.
    }catch (let err) {
      response.appendBody(string: "<html><H1>AUTHENTICATION FAILED: \(err)</H1></html>\n")
    }//end du
    response.completed()
	}
}


let confData = [
	"servers": [
		// Configuration data for one server which:
		//	* Serves the hello world message at <host>:<port>/
		//	* Serves static files out of the "./webroot"
		//		directory (which must be located in the current working directory).
		//	* Performs content compression on outgoing data when appropriate.
		[
			"name":"localhost",
			"port":port,
			"routes":[
				["method":"get", "uri":"/", "handler":handler],
				["method":"get", "uri":"/**", "handler":PerfectHTTPServer.HTTPHandler.staticFiles,
				 "documentRoot":"./webroot",
				 "allowResponseFilters":true]
			],
			"filters":[
				[
				"type":"response",
				"priority":"high",
				"name":PerfectHTTPServer.HTTPFilter.contentCompression,
				]
			]
		]
	]
]

do {
	// Launch the servers based on the configuration data.
	try HTTPServer.launch(configurationData: confData)
} catch {
	fatalError("\(error)") // fatal error launching one of the servers
}
