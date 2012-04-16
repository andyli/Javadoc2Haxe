package javadoc2haxe;

import js.Lib;
import jQuery.JQuery;
import javadoc2haxe.Request;

class ContentScript {	
	static function main():Void {
		if (JavaToHaxe.isJavadocClassPage()) {
			chrome.Extension.sendRequest(showPageAction);
			
			new JQuery(Lib.window).bind('beforeunload', function(){ 
				chrome.Extension.sendRequest(hidePageAction);
			});
		}
	}
}
