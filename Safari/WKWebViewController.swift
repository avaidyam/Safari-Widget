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

let scrollers_css = """
::-webkit-scrollbar {
    -webkit-appearance: none;
}

::-webkit-scrollbar:vertical {
    width: 11px;
}

::-webkit-scrollbar:horizontal {
    height: 11px;
}

::-webkit-scrollbar-thumb {
    border-radius: 8px;
    border: 2px solid white; /* should match background, can't be transparent */
    background-color: rgba(0, 0, 0, .5);
}

::-webkit-scrollbar-track {
    background-color: #fff;
    border-radius: 8px;
}
"""
let scrollers_script = "var style = document.createElement('style'); style.innerHTML = '::-webkit-scrollbar{-webkit-appearance:none}::-webkit-scrollbar:vertical{width:11px}::-webkit-scrollbar:horizontal{height:11px}::-webkit-scrollbar-thumb{border-radius:8px;border:2px solid #fff;background-color:rgba(0,0,0,.5)}'; document.head.appendChild(style);"

// To render the above (or any) string.
func render(str: String, dict: Dictionary<String, String>, sep: String = "%") -> String {
    var str = str
    for (key, value) in dict {
        str = str.replacingOccurrences(of: sep + "\(key)" + sep, with: value)
	}
	return str
}

class WKWebViewController: NSViewController, WKUIDelegate, WKNavigationDelegate, NSSharingServicePickerDelegate {
	
	let agent = "Mozilla/5.0 (iPhone; CPU iPhone OS 9_0 like Mac OS X) AppleWebKit/601.1.16 (KHTML, like Gecko) Version/8.0 Mobile/13A175 Safari/600.1.4"
	let siteKey = "WEB_SITE_KEY"
    let defaults = UserDefaults.standard
	
	@IBOutlet var webView: WKWebView?
	@IBOutlet var refresh: NSButton?
	@IBOutlet var address: NSTextField?
	@IBOutlet var toolbar: NSVisualEffectView?
	@IBOutlet var progress: NSProgressIndicator?
	
	override var nibName: NSNib.Name? {
		return NSNib.Name(rawValue: self.className)
	}
	
	override func loadView() {
		super.loadView()
		self.preferredContentSize = CGSize(width: 320, height: 568)
        
        let configuration = WKWebViewConfiguration()
        let script = WKUserScript(source: scrollers_script, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        configuration.userContentController.addUserScript(script)
        
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        configuration.preferences = preferences
        
		// Configure webView
        self.webView = WKWebView(frame: self.view.bounds, configuration: configuration)
		self.webView!.uiDelegate = self
		self.webView!.navigationDelegate = self
		self.webView!.addObserver(self, forKeyPath: "estimatedProgress", options: .new, context: nil)
        
		// Configure toolbar and subviews
		var rect = self.view.bounds
		rect.origin.y = rect.size.height - 26
		rect.size.height = 26
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
            self.toolbar!.isHidden = true
		}
        self.progress!.isHidden = true
		var site = "http://www.apple.com/"
        if defaults.string(forKey: siteKey) != nil {
            site = defaults.string(forKey: siteKey)!
		}
		self.address!.stringValue = site
        self.webView!.load(URLRequest(url: URL(string:site)!))
	}
	
	deinit {
		
		// Clean up after webView
		self.webView!.removeObserver(self, forKeyPath: "estimatedProgress")
		self.webView!.uiDelegate = nil
		self.webView!.navigationDelegate = nil
	}
	
	// ---------
	
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping ((WKNavigationActionPolicy) -> Void)) {
		let _ = navigationAction.request.url
		switch navigationAction.navigationType {
        case .linkActivated:
				if navigationAction.targetFrame == nil {
                    self.webView?.load(navigationAction.request)
				}
			default:
				break
		}
        decisionHandler(.allow)
	}
	
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping ((WKNavigationResponsePolicy) -> Void)) {
        decisionHandler(.allow)
	}
	
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation) {
        self.refresh!.state = .on
        self.progress!.animator().isHidden = false
	}
	
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation) {
        defaults.set((self.webView!.url?.absoluteString)!, forKey: siteKey)
        self.address!.stringValue = (self.webView!.url?.absoluteString)!
	}
	
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
		
		// Only handle HTTP form authentication
		guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic ||
			challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPDigest else {
                completionHandler(.performDefaultHandling, nil)
				return
		}
		
		// Create an alert and pre-fill info
		let alert = NSAlert()
        alert.messageText = (self.webView!.url?.host)!
		alert.informativeText = "Authentication Required"
		alert.alertStyle = .critical
        alert.addButton(withTitle: "Authenticate")
        alert.addButton(withTitle: "Cancel")
		
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
        if alert.runModal() == .alertFirstButtonReturn {
            let credential = URLCredential(user: username.stringValue,
                                           password: password.stringValue, persistence: .forSession)
            completionHandler(.useCredential, credential)
		} else {
            completionHandler(.rejectProtectionSpace, nil)
		}
	}
	
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation) {
		
	}
	
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
		self.refresh!.state = .off
        self.progress!.animator().isHidden = true
	}
	
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation, withError error: Error) {
		self.refresh!.state = .off
        self.progress!.animator().isHidden = true
        loadErrorPage(error: error)
	}
	
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation, withError error: Error) {
		self.refresh!.state = .off
		self.progress!.animator().isHidden = true
		loadErrorPage(error: error)
	}
	
	// ---------
	
	func loadErrorPage(error: Error) {
        self.webView!.loadHTMLString(render(str: FAILED_TO_OPEN_PAGE, dict: [
            "title": "Error \(error._code)",
			"message": error.localizedDescription
			]), baseURL: nil)
	}
	
	// ---------
	
	func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (() -> Void)) {
		
		// Create an alert and run it
		let alert = NSAlert()
		alert.messageText = (frame.request.url?.host)!
		alert.informativeText = message
		alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
		alert.runModal()
		completionHandler()
	}
	
	func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ((Bool) -> Void)) {
		
		// Create an alert and run it
		let alert = NSAlert()
		alert.messageText = (frame.request.url?.host)!
		alert.informativeText = message
		alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        completionHandler((alert.runModal() == .alertFirstButtonReturn))
	}
	
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
		
		// Create an alert and pre-fill info
		let alert = NSAlert()
		alert.messageText = (frame.request.url?.host)!
		alert.informativeText = prompt
		alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
		
		// Add an input accessory field
		let input = NSTextField(frame: NSMakeRect(0, 0, 200, 24))
		input.stringValue = defaultText!
		alert.accessoryView = input
		
		// Run the alert and return the input
        if alert.runModal() == .alertFirstButtonReturn {
			completionHandler(input.stringValue)
		} else {
			completionHandler(nil)
		}
	}
	
	// ---------
    
	@IBAction func navigatePage(_ sender: NSSegmentedControl) {
		if sender.integerValue == 0 { // back
			self.webView!.goBack()
		} else if sender.integerValue == 1 { // forward
			self.webView!.goForward()
		}
	}
	
	@IBAction func refreshOrStop(_ sender: NSButton) {
		if sender.state == .off { // loaded/refresh visible
			self.webView!.stopLoading()
		} else if sender.state == .on { // loading/stop visible
			self.webView!.reloadFromOrigin()
		}
	}
	
	@IBAction func goURL(_ sender: NSTextField) {
        var str = sender.stringValue
        if !(str.hasPrefix("http://") || str.hasPrefix("https://")) {
            str = "http://" + str
        }
        
        defaults.set(str, forKey: siteKey)
        self.webView!.load(URLRequest(url: URL(string: str)!))
	}
	
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath! == "estimatedProgress" {
            self.progress!.animator().doubleValue = (self.webView?.estimatedProgress)! * 100
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
}

// Support NCWidgetProviding for Today stuff
extension WKWebViewController: NCWidgetProviding {
	public func widgetMarginInsets(forProposedMarginInsets defaultMarginInset: NSEdgeInsets) -> NSEdgeInsets {
		return NSEdgeInsetsZero
	}
	public func widgetPerformUpdate(completionHandler: @escaping (NCUpdateResult) -> Swift.Void) {
        completionHandler(.newData)
	}
	var widgetAllowsEditing: Bool {
		return true
	}
	func widgetDidBeginEditing() {
        self.toolbar!.animator().isHidden = false
	}
	func widgetDidEndEditing() {
        self.toolbar!.animator().isHidden = true
	}
}
