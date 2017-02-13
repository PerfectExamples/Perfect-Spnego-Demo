# Perfect SPNEGO demo [English](https://github.com/PerfectlySoft/PerfectTemplate)

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

包含有SPNEGO 功能的 Perfect 项目模板

本项目是基于[PerfectTemplate 服务器模板](https://github.com/PerfectlySoft/PerfectTemplate)。如果您还不熟悉PerfectTemplate，请最好先尝试一下。

## 编译指南

本项目使用 **Swift 3.0.2** 工具链，支持Ubuntu 和Mac OS X

### Xcode 编译指南

如果您希望使用 Xcode 编译该项目，请确保将下列编译标识正确传递给SPM 软件包管理器：

```
$ swift package -Xlinker -framework -Xlinker GSS generate-xcodeproj
```

### Linux 编译指南

编译本项目之前请确保 libkrb5-dev 函数库已经正确安装。

```
$ sudo apt-get install libkrb5-dev
```

## KDC配置

请配置好您的应用服务器/etc/krb5.conf，以便于该服务器能够正常连接到目标的KDC。请参考下面的例子，在这个例子中，应用服务器希望连接到控制区域`KRB5.CA`，并且该控制区域的KDC控制中心域名为`nut.krb5.ca`:

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

## 准备Kerberos 授权钥匙

下一步需要联系您的KDC 管理员，获得应用服务器将使用的keytab钥匙文件。

参考下面的例子的示范配置，⚠️下列所有主机必须注册到同一个DNS⚠️

- KDC 安全控制中心服务器: nut.krb5.ca
- 应用服务器: apple.krb5.ca
- 应用服务器计划安装的协议类型: HTTP

如果处于上述环境，则KDC管理员需要登录`nut.krb5.ca` 控制区域并采取下列操作：

```
kadmin.local: addprinc -randkey HTTP/apple.krb5.ca@KRB5.CA
kadmin.local: ktadd -k /tmp/krb5.keytab HTTP/apple.krb5.ca@KRB5.CA
```

生成钥匙文件krb5.keytab后，请将该钥匙安全地传输到您的应用服务器`apple.krb5.ca`并将文件移动到目录`/etc`下，然后赋予其适当权限，以便于您的服务器可以访问到。


## 编译和运行

运行下列命令可以编译本项目并在8080端口上启动包含SPNEGO机制的服务器。

```
git clone https://github.com/PerfectExamples/Perfect-SPNEGO-Demo.git
cd Perfect-SPNEGO-Demo
swift build
.build/debug/PerfectTemplate
```

可以看到服务器运行后的启动信息：

```
SPNEGO IS READY
[INFO] Starting HTTP server localhost on 0.0.0.0:8080
```

证明服务器已经准备好。

现在您可以尝试访问一下 `http://apple.krb5.ca:8080` 看看会发生什么事情。

如果您正在使用兼容 SPNEGO 的浏览器，那么可能会看到一个登录框，提示输入用户名密码。
或者，您可以使用下列命令行用于更清楚地理解整个验证过程：

```
$ kinit
$ curl -v --negotiate -u : http://apple.krb5.ca:8080
```

此时，应该可以注意到，如果没有使用 kinit 登录，则 curl 返回的是禁止访问。

### URL 说明

请注意如果希望能够保证该范例能够正确运行，请使用 FQDN (完全限定域名) 来配置URL路径，而不是使用 `localhost` 或IP地址，并且服务器和客户端都需要配置为这种域名。

## SPNEGO 验证过程

示范代码在原有 PerfectTemplate 基础上追加了几行程序，用于验证用户身份：

首先，接收到客户请求后，初始化了一个SPNEGO 对象。
随后，处理器会将HTTP响应设置为`.unauthorized`表示需要授权，即指示客户端必须提供SPNEGO的有效凭证进行身份验证。
如果HTTP请求中已经包含了一个 Base64 编码的票据，那么服务器应该尝试使用这个方法接收票据并获取用户身份信息：` let (username, reply_token) = try spnego.accept(base64Token: inputToken)`

如果返回的用户名非空，则确认用户身份已经验证。此时您可能需要额外的ACL（访问控制列表）进一步验证用户是否有权访问当前URL指向的资源，否则应该拒绝该请求。

请注意返回的另外一个参数`reply_token`如果非空，则需要发回给客户端以完成整个验证过程。


```swift
import PerfectSPNEGO
import Darwin
// 注意，主机名必须是完全限制名称 FQDN，并且已经在KDC上注册登记并获取合法keytab文件。
let hostname = "apple.krb5.ca"

// 收到安全保护的请求处理器
func handler(data: [String:Any]) throws -> RequestHandler {
	return {
		request, response in

		// 首先将返回状态设置为禁止访问
    response.status = .unauthorized

    // 服务器和客户机时间必须同步，因此返回一个GMT时间
    response.setHeader(.date, value: GMTNow())

    // 提示客户机必须进行协议协商
    response.setHeader(.wwwAuthenticate, value: "Negotiate")
    response.setHeader(.contentType, value: "text/html")

    // 如果客户机无有效凭证则拒绝访问
    guard let auth = request.header(.custom(name: "Authorization")) else {
      response.appendBody(string: "<html><H1>ACCESS DENIED</H1></html>\n")
      response.completed()
      return
    }//end auth

    // 从客户机请求中提取身份验证票据凭证
    let negotiate = "Negotiate "
    guard auth.hasPrefix(negotiate) else {
      response.appendBody(string: "<html><H1>INVALID TOKEN FORMAT</H1></html>\n")
      response.completed()
      return
    }//end auth.prefix

    // 将凭证转化为标准格式
    let inputToken = String(auth.characters.dropFirst(negotiate.utf8.count))
    do {

      let spnego = try Spnego("HTTP@\(hostname)")

      // 尝试接收申请
      let (username, outputToken) = try spnego.accept(base64Token: inputToken)

      // 检查服务器是否需要返回收条
      if let reply = outputToken {
        response.setHeader(.custom(name: "Authorization"), value:"Negotiate \(reply)")
      }//end if

      // 检查是否已经完成身份验证
      if let user = username {

        // 用户登录已经成功
        // 注意，在生产服务器中，您可能需要进一步使用ACL 安全访问列表来检查已验证身份的用户是否有足够的权限访问当前URL资源
        response.status = .accepted

        // 返回受保护的资源内容
        response.appendBody(string: "<html><title>Hello, world!</title><body>Welcome, \(user)</body></html>\n")

      }else {

        // 验证失败，有可能是DNS错误造成，请务必使用FQDN完全限制域名
        response.appendBody(string: "<html><H1>GSS REQUEST TO CALL IT ONCE MORE</H1></html>\n")
      }//end if
    }catch (let err) {

      // 用户身份验证失败
      response.appendBody(string: "<html><H1>AUTHENTICATION FAILED: \(err)</H1></html>\n")
    }//end du

    // 完成身份验证
    response.completed()
	}
}

```



## 问题报告

目前我们已经把所有错误报告合并转移到了JIRA上，因此github原有的错误汇报功能不能用于本项目。

您的任何宝贵建意见或建议，或者发现我们的程序有问题，欢迎您在这里告诉我们。[http://jira.perfect.org:8080/servicedesk/customer/portal/1](http://jira.perfect.org:8080/servicedesk/customer/portal/1)。

目前问题清单请参考以下链接： [http://jira.perfect.org:8080/projects/ISS/issues](http://jira.perfect.org:8080/projects/ISS/issues)



## 更多内容
关于Perfect更多内容，请参考[perfect.org](http://perfect.org)官网。
