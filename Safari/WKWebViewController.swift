import Cocoa
import WebKit
import NotificationCenter

let FAILED_TO_OPEN_PAGE =
"<html>" +
"<head>" +
"    <style>" +
"body {" +
"    background: rgb(246, 246, 246);" +
"    cursor: default;" +
"    display: -webkit-box;" +
"    text-align: center;" +
"    font-family:'-webkit-system-font';" +
"    -webkit-box-align: center;" +
"    -webkit-box-pack: center;" +
"    -webkit-user-select: none;" +
"}" +
"" +
"a {" +
"    color: rgb(21, 126, 251);" +
"    text-decoration: none;" +
"}" +
"" +
"input {" +
"    font-size: 16px;" +
"}" +
"" +
".content-container {" +
"    min-width: 320px;" +
"    max-width: 580px;" +
"    margin: 0 auto;" +
"    position: relative;" +
"    width: 50%;" +
"}" +
"" +
".error-title {" +
"    font-size: 28px;" +
"    line-height: 34px;" +
"    margin: 0 auto;" +
"}" +
"" +
".error-message, .suggestion-prompt {" +
"    font-size: 13px;" +
"    line-height: 18px;" +
"    padding: 0px 24px;" +
"}" +
"" +
".suggestion-form {" +
"    display: inline-block;" +
"    margin: 5px;" +
"}" +
"" +
".suggestion-form input {" +
"    margin: 0;" +
"    min-width: 146px;" +
"}" +
"" +
".text-container {" +
"    color: rgb(133, 133, 133);" +
"    position: relative;" +
"    width: 100%;" +
"    word-wrap: break-word;" +
"}" +
"    </style>" +
"    <title>Failed to open page</title>" +
"</head>" +
"<body>" +
"    <div class=\"content-container\">" +
"        <div class=\"error-container\">" +
"            <div class=\"text-container\">" +
"                <p class=\"error-title\">%title%</p>" +
"            </div>" +
"            <div class=\"text-container\">" +
"                <p class=\"error-message\">%message%</p>" +
"            </div>" +
"        </div>" +
"    </div>" +
"</body>" +
"</html>";

// To render the above (or any) string.
func render(var str: String, dict: Dictionary<String, String>, sep: String = "%") -> String {
	for (key, value) in dict {
		str = str.stringByReplacingOccurrencesOfString(sep + "\(key)" + sep, withString: value)
	}
	return str
}

class WKWebViewController: NSViewController, WKUIDelegate, WKNavigationDelegate, NSSharingServicePickerDelegate {
	
	let agent = "Mozilla/5.0 (iPhone; CPU iPhone OS 9_0 like Mac OS X) AppleWebKit/601.1.16 (KHTML, like Gecko) Version/8.0 Mobile/13A175 Safari/600.1.4"
	let siteKey = "WEB_SITE_KEY"
	let defaults = NSUserDefaults.standardUserDefaults()
	
	@IBOutlet var webView: WKWebView?
	@IBOutlet var refresh: NSButton?
	@IBOutlet var address: NSTextField?
	@IBOutlet var toolbar: NSVisualEffectView?
	@IBOutlet var progress: NSProgressIndicator?
	
	override var nibName: String? {
		return self.className
	}
	
	override func loadView() {
		super.loadView()
		self.preferredContentSize = CGSizeMake(320, 568)
		
		// Configure webView
		self.webView = WKWebView(frame: self.view.bounds)
		self.webView!.UIDelegate = self
		self.webView!.navigationDelegate = self
		self.webView!.addObserver(self, forKeyPath: "estimatedProgress", options: .New, context: nil)
		
		// Configure toolbar and subviews
		var rect = self.view.bounds
		rect.origin.y = rect.size.height - 32
		rect.size.height = 32
		self.view.addSubview(self.webView!)
		self.view.addSubview(self.toolbar!)
		self.toolbar!.frame = rect
		
		// Configure WKWebView
		self.webView?.allowsMagnification = true
		self.webView?.allowsBackForwardNavigationGestures = true
		self.webView?.allowsLinkPreview = true
		self.webView?.customUserAgent = agent
		
		// Load the page and display it
		if self.extensionContext != nil {
			self.toolbar!.hidden = true
		}
		self.progress!.hidden = true
		var site = "http://www.apple.com/"
		if defaults.stringForKey(siteKey) != nil {
			site = defaults.stringForKey(siteKey)!
		}
		self.address!.stringValue = site
		self.webView!.loadRequest(NSURLRequest(URL: NSURL(string:site)!))
	}
	
	deinit {
		
		// Clean up after webView
		self.webView!.removeObserver(self, forKeyPath: "estimatedProgress")
		self.webView!.UIDelegate = nil
		self.webView!.navigationDelegate = nil
	}
	
	// ---------
	
	func webView(webView: WKWebView, decidePolicyForNavigationAction navigationAction: WKNavigationAction,
		decisionHandler: ((WKNavigationActionPolicy) -> Void)) {
		let _ = navigationAction.request.URL
		switch navigationAction.navigationType {
			case .LinkActivated:
				if navigationAction.targetFrame == nil {
					self.webView?.loadRequest(navigationAction.request)
				}
			default:
				break
		}
		decisionHandler(.Allow)
	}
	
	func webView(webView: WKWebView, decidePolicyForNavigationResponse navigationResponse: WKNavigationResponse,
		decisionHandler: ((WKNavigationResponsePolicy) -> Void)) {
		decisionHandler(.Allow)
	}
	
	func webView(webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation) {
		self.refresh!.state = 1
		self.progress!.animator().hidden = false
	}
	
	func webView(webView: WKWebView, didCommitNavigation navigation: WKNavigation) {
		defaults.setObject((self.webView!.URL?.absoluteString)!, forKey: siteKey)
		self.address!.stringValue = (self.webView!.URL?.absoluteString)!
	}
	
	func webView(webView: WKWebView, didReceiveAuthenticationChallenge challenge: NSURLAuthenticationChallenge,
		completionHandler: (NSURLSessionAuthChallengeDisposition, NSURLCredential?) -> Void) {
		
		// Only handle HTTP form authentication
		guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic ||
			challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPDigest else {
				completionHandler(.PerformDefaultHandling, nil)
				return
		}
		
		// Create an alert and pre-fill info
		let alert = NSAlert()
		alert.messageText = (self.webView!.URL?.host)!
		alert.informativeText = "Authentication Required"
		alert.alertStyle = .CriticalAlertStyle
		alert.addButtonWithTitle("Authenticate")
		alert.addButtonWithTitle("Cancel")
		
		// Add username and password accessory fields
		let username = NSTextField(frame: NSMakeRect(0, 28, 200, 24))
		let password = NSSecureTextField(frame: NSMakeRect(0, 0, 200, 24))
		let view = NSView(frame: NSMakeRect(0, 0, 200, 52))
		username.placeholderString = "Username"
		password.placeholderString = "Password"
		view.addSubview(username)
		view.addSubview(password)
		alert.accessoryView = view
		
		// Run the alert and return the input
		if alert.runModal() == NSAlertFirstButtonReturn {
			let credential = NSURLCredential(user: username.stringValue,
				password: password.stringValue, persistence: .ForSession)
			completionHandler(.UseCredential, credential)
		} else {
			completionHandler(.RejectProtectionSpace, nil)
		}
	}
	
	func webView(webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation) {
		
	}
	
	func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation) {
		self.refresh!.state = 0
		self.progress!.animator().hidden = true
	}
	
	func webView(webView: WKWebView, didFailNavigation navigation: WKNavigation, withError error: NSError) {
		self.refresh!.state = 0
		self.progress!.animator().hidden = true
		loadErrorPage(error)
	}
	
	func webView(webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation, withError error: NSError) {
		self.refresh!.state = 0
		self.progress!.animator().hidden = true
		loadErrorPage(error)
	}
	
	// ---------
	
	func loadErrorPage(error: NSError) {
		self.webView!.loadHTMLString(render(FAILED_TO_OPEN_PAGE, dict: [
			"title": "Error \(error.code)",
			"message": error.localizedDescription
			]), baseURL: nil)
	}
	
	// ---------
	
	func webView(webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
		initiatedByFrame frame: WKFrameInfo, completionHandler: (() -> Void)) {
		
		// Create an alert and run it
		let alert = NSAlert()
		alert.messageText = (frame.request.URL?.host)!
		alert.informativeText = message
		alert.alertStyle = .InformationalAlertStyle
		alert.addButtonWithTitle("OK")
		alert.addButtonWithTitle("Cancel")
		alert.runModal()
		completionHandler()
	}
	
	func webView(webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
		initiatedByFrame frame: WKFrameInfo, completionHandler: ((Bool) -> Void)) {
		
		// Create an alert and run it
		let alert = NSAlert()
		alert.messageText = (frame.request.URL?.host)!
		alert.informativeText = message
		alert.alertStyle = .InformationalAlertStyle
		alert.addButtonWithTitle("OK")
		alert.addButtonWithTitle("Cancel")
		completionHandler((alert.runModal() == NSAlertFirstButtonReturn))
	}
	
	func webView(webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
		defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: (String?) -> Void) {
		
		// Create an alert and pre-fill info
		let alert = NSAlert()
		alert.messageText = (frame.request.URL?.host)!
		alert.informativeText = prompt
		alert.alertStyle = .InformationalAlertStyle
		alert.addButtonWithTitle("OK")
		alert.addButtonWithTitle("Cancel")
		
		// Add an input accessory field
		let input = NSTextField(frame: NSMakeRect(0, 0, 200, 24))
		input.stringValue = defaultText!
		alert.accessoryView = input
		
		// Run the alert and return the input
		if alert.runModal() == NSAlertFirstButtonReturn {
			completionHandler(input.stringValue)
		} else {
			completionHandler(nil)
		}
	}
	
	// ---------
	
	@IBAction func navigatePage(sender: NSSegmentedControl) {
		if sender.integerValue == 0 { // back
			self.webView!.goBack()
		} else if sender.integerValue == 1 { // forward
			self.webView!.goForward()
		}
	}
	
	@IBAction func refreshOrStop(sender: NSButton) {
		if sender.state == 0 { // loaded/refresh visible
			self.webView!.stopLoading()
		} else if sender.state == 1 { // loading/stop visible
			self.webView!.reloadFromOrigin()
		}
	}
	
	@IBAction func goURL(sender: NSTextField) {
		defaults.setObject(sender.stringValue, forKey: siteKey)
		self.webView!.loadRequest(NSURLRequest(URL: NSURL(string:sender.stringValue)!))
	}
	
	override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
		if keyPath! == "estimatedProgress" {
			self.progress!.animator().doubleValue = (self.webView?.estimatedProgress)! * 100
		} else {
			super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
		}
	}
}

// Support NCWidgetProviding for Today stuff
extension WKWebViewController: NCWidgetProviding {
	func widgetMarginInsetsForProposedMarginInsets(defaultMarginInset: NSEdgeInsets) -> NSEdgeInsets {
		return NSEdgeInsetsZero
	}
	func widgetPerformUpdateWithCompletionHandler(completionHandler: ((NCUpdateResult) -> Void)!) {
		completionHandler(.NewData)
	}
	var widgetAllowsEditing: Bool {
		return true
	}
	func widgetDidBeginEditing() {
		self.toolbar!.animator().hidden = false
	}
	func widgetDidEndEditing() {
		self.toolbar!.animator().hidden = true
	}
}
