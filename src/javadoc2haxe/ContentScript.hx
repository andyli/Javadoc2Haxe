package javadoc2haxe;

import js.Lib;
import jQuery.JQuery;

class ContentScript {	
	static function main():Void {
		if (Javadoc2Haxe.isJavadocClassPage()) {			
			var j2hLogo = chrome.Extension.getURL("Javadoc2Haxe-logo.png");
			var j2h = chrome.Extension.getURL("javadoc2haxe.js");
			
			new JQuery("<a href='#' title='generate Haxe extern'><img src='"+j2hLogo+"' /></a>")
				.click(function() {
					JQuery._static.getScript(j2h);
					return false;
				})
				.appendTo("h2:first");
		}
	}
}
