package javadoc2haxe;

import js.Lib;
import jQuery.JQuery;
using Lambda;
using org.casalib.util.StringUtil;
using StringTools;
using Reflect;

typedef Function = {
	name:String,
	args:Array<Var>,
	ret:String,
	isStatic:Bool,
	?comment:String
}

typedef Var = {
	name:String, 
	type:String,
	?isStatic:Bool
}

class JavaToHaxe {
	static function __init__():Void {
		haxe.macro.Tools.includeFile("jquery-1.7.2.min.js");
		haxe.macro.Tools.includeFile("jquery-ui-1.8.18.custom.min.js");
	}
	
	static public function isJavadocClassPage():Bool {
		return	(new JQuery("th:contains('Constructor Summary')").length == 1 ||
				new JQuery("th:contains('Method Summary')").length == 1 ||
				new JQuery("th:contains('Field Summary')").length == 1) &&
				new JQuery("b:contains('Class')").length > 0;
				
	}
	
	static public function isJavadocPage():Bool {
		return	new JQuery("frame[name='packageListFrame']").length == 1 &&
				new JQuery("frame[name='packageFrame']").length == 1 &&
				new JQuery("frame[name='classFrame']").length == 1;
	}
	
	static public function removeExtraSpaces(str:String):String {
		var len;
		do {
			len = str.length;
			str = ~/\s\s/g.replace(str, " ");
			str = ~/[\n\r]*/g.replace(str, "");
		} while (len != str.length);
		
		return str;
	}
	
	/*
	 * Map Java type to Haxe type
	 */
	static public function mapType(t:String):String {
		return switch(JQuery._static.trim(t)) {
			case "byte": "Int"; //"Int8";
			case "short": "Int"; //"Int16";
			case "int": "Int";
			case "long": "Int"; //"Int64";
			case "char": "Int"; //"Char16";
			case "float": "Single";
			case "double": "Float";
			case "string", "java.lang.String": "String";
			case "boolean": "Bool";
			case "void": "Void";
			case "Object", "java.lang.Object": "Dynamic";
			default:
				var array = t.lastIndexOf("[]");
				array == -1 ? t : "jvm.NativeArray<" + mapType(t.substr(0, array)) + ">";
		}
	}
	
	/*
	 * Format "int value" into Var
	 */
	static public function processVar(a:String):Var {
		var r = ~/(.*\s*)\s+(.*)/;
		if (!r.match(a)) throw "Cannot extract variable type and name from " + a;
		
		return {
			name: r.matched(2),
			type: mapType(r.matched(1))
		}
	}
	
	/*
	 * Format "int value" into "value:Int"
	 */
	static public function formatVar(a:Var):String {
		return a.name + ":" + a.type;
	}
	
	/*
	 * Format Function.
	 */
	static public function formatFunction(f:Function):String {
		return (f.hasField("isStatic") && f.isStatic ? "static " : "") + "public function " + f.name + "(" + f.args.map(formatVar).join(", ") + "):" + f.ret + ";";
	}
	/*
	 * Format Function as @:overload.
	 */
	static public function formatFunctionOverload(f:Function):String {
		return "@:overload(function(" + f.args.map(formatVar).join(", ") + "):" + f.ret + "{})";
	}
	
	static function argTypeIsDynamic(a:Var):Bool {
		return a.type == "Dynamic";
	}
	
	static var typeOrder = {
		var t = ["Void", "Bool", "Int", "Int8", "Char16", "Int16", "Int64", "Single", "Float", "String"];
		var to = t.concat(t.map(function(s) return "jvm.NativeArray<" + s + ">").array());
		to.reverse();
		to;
	}
	
	static public function sortArgs(a0:Array<Var>, a1:Array<Var>):Int {
		for (i in 0...a0.length) {
			var v0 = typeOrder.indexOf(a0[i].type);
			if (v0 == -1 && a0[i].type == "Dynamic") v0 = -2;
			var v1 = typeOrder.indexOf(a1[i].type);
			if (v1 == -1 && a1[i].type == "Dynamic") v1 = -2;
			var d = v1 - v0;
			if (d != 0) return d;
		}
		return 0;
	}
	
	/*
	 * Sort Vars(fields)
	 */
	static public function sortVar(f0:Var, f1:Var):Int {
		return Reflect.compare(f0.name, f1.name);
	}
	
	/*
	 * Sort Functions so that more "Dynamic" ones come last.
	 */
	static public function sortFunctions(f0:Function, f1:Function):Int {
		var n = Reflect.compare(f0.name, f1.name);
		return n != 0 ? n : 
			f0.args.length == f1.args.length ? 
				sortArgs(f0.args, f1.args) : 
				f0.args.length - f1.args.length;
	}
	
	static public function extractClassType(c:String):{ classTypes:Array<String>, name:String } {
		var a = [];
		var classDef = ~/[\s]+/.split(c).filter(function(s) return s.length > 0);
		for (n in classDef) {
			switch(n) {
				case "abstract":
				case "Class": a.push("class");
				case "Interface": a.push("interface");
			}
		}
		return { classTypes:a.array(), name:classDef.last() }
	}
	
	static public function formatFunctions(fs:Array<Function>):String {
		fs.sort(sortFunctions);
		
		var fsgroup = new Array<Array<Function>>();
		var g = new Array<Function>();
		for (f in fs) {
			if (g.length == 0 || g[0].name == f.name) {
				g.push(f);
			} else {
				fsgroup.push(g);
				g = [f];
			}
		}
		fsgroup.push(g);
		
		var methodsStr = "\t";
		for (g in fsgroup) {
			if (g.length == 1) {
				methodsStr += formatFunction(g[0]) + "\n\t\n\t";
			} else if (g.length > 1) {
				var overload = "";
				for (i in 1...g.length) {
					overload += formatFunctionOverload(g[i]) + "\n\t";
				}
				methodsStr += overload + formatFunction(g[0]) + "\n\t\n\t";
			}
		}
		return methodsStr;
	}
	
	static public function main():Void {	
		var classFrame = new JQuery("body");
		
		var classH2 = classFrame.find("h2:first");
		var classPack = JQuery._static.trim(classH2.find("font").text());
		var c = extractClassType(removeExtraSpaces(JQuery._static.trim(classH2.text().replace(classPack, ""))));
		var className = c.name;
		var classType = c.classTypes.join(" ");
		
		/*
		 * Fields
		 */
		var fields = new Array<Var>();
		classFrame.find("table").has("tr:contains('Field Summary')").find("tr").each(function(i, v){
			if (new JQuery(v).find("code").length == 0) return;
			
		    var type:String = removeExtraSpaces(new JQuery(v).find("td:nth-child(1) code").text()).trim();
		    
		    var rStatic = ~/static\s/;
		    var isStatic = rStatic.match(type);
		    if (isStatic) {
		    	type = rStatic.replace(type, "");
		    }
			type = removeExtraSpaces(type);
			type = mapType(type);
			
			var name = new JQuery(v).find("td:nth-child(2) code:first").text().trim();
			name = removeExtraSpaces(name);
			
			fields.push({
				name: name,
				type: type,
				isStatic: isStatic
			});	
		});
		fields.sort(sortVar);
		var fieldsStr = fields.map(function(f) return (f.isStatic ? "static " : "") + "public var " + f.name + ":" + f.type + ";").join("\n\t");
		
		/*
		 * Methods
		 */
		var methods = new Array<Function>();
		classFrame.find("table").has("tr:contains('Method Summary')").find("tr").each(function(i, v){
			if (new JQuery(v).find("code").length == 0) return;
			
		    var returnType:String = removeExtraSpaces(new JQuery(v).find("td:nth-child(1) code").text()).trim();
		    
		    var rStatic = ~/static\s/;
		    var isStatic = rStatic.match(returnType);
		    if (isStatic) {
		    	returnType = rStatic.replace(returnType, "");
		    }
		    returnType = returnType.remove("abstract ");
			returnType = removeExtraSpaces(returnType);
			returnType = mapType(returnType);
			
			var fun = new JQuery(v).find("td:nth-child(2) code:first").text().trim();
			fun = removeExtraSpaces(fun);
			
			var rArgs = ~/\(.*\)/;
			if (!rArgs.match(fun)) throw "Cannot find params of " + fun;
			var args = rArgs.matched(0);
			args = args.substr(1, args.length-2);
			
			methods.push({
				name: fun.substr(0, fun.indexOf("(")).trim(),
				args: args.length > 0 ? args.split(",").map(processVar).array() : [],
				ret: returnType,
				isStatic: isStatic
			});	
		});
		
		var methodsStr = formatFunctions(methods);
		
		
		/*
		 * Constructors
		 */
		var news = new Array<Function>();
		classFrame.find("table").has("tr:contains('Constructor Summary')").find("tr").each(function(i, v){
			if (new JQuery(v).find("code").length == 0) return;
			
		    var returnType = "Void";
			
			var fun = new JQuery(v).find("td:nth-child(1) code:first").text().trim();
			fun = removeExtraSpaces(fun);
			
			var rArgs = ~/\(.*\)/;
			if (!rArgs.match(fun)) throw "Cannot find params of " + fun;
			var args = rArgs.matched(0);
			args = args.substr(1, args.length-2);
			
			news.push({
				name: "new",
				args: args.length > 0 ? args.split(",").map(processVar).array() : [],
				ret: "Void",
				isStatic: false
			});	
		
		});
		
		var newsStr = formatFunctions(news);
		
		var out = "package " + classPack + ";\n\n" +
			"#if !jvm private typedef Single = Float; #end\n\n" +
			"extern " + classType + " " + className + " {\n\n" + 
			fieldsStr + "\n\n" +
			(newsStr.length > 1 ? newsStr + "\n" : "") + 
			methodsStr + "\n" +
			"}";
		
		new JQuery('head').append(new JQuery('<link rel="stylesheet" type="text/css" />').attr('href', "http://ajax.googleapis.com/ajax/libs/jqueryui/1.8.18/themes/ui-lightness/jquery-ui.css"));
		var dialog = new JQuery('<div title="JavaToHaxe output"></div>');
		var textarea:JQuery = new JQuery('<textarea>'+out+'</textarea>').width("100%").height("100%").appendTo(dialog);
		untyped dialog.appendTo(classFrame).dialog({
			width: 800,
			height: 600,
			modal: true
		});
		
		textarea.focus();
		textarea.select();
		
		//Lib.alert(newsStr + "\n\n" + methodsStr);
	}
}