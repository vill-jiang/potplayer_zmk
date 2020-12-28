/*
	subtitle search by zimuku
*/

// string GetTitle() 																-> get title for UI
// string GetVersion																-> get version for manage
// string GetDesc()																	-> get detail information
// string GetLoginTitle()															-> get title for login dialog
// string GetLoginDesc()															-> get desc for login dialog
// string ServerCheck(string User, string Pass) 									-> server check
// string ServerLogin(string User, string Pass) 									-> login
// string GetLanguages()															-> get support language
// string SubtitleWebSearch(string MovieFileName, dictionary MovieMetaData)			-> search subtitle by web browser
// array<dictionary> SubtitleSearch(string MovieFileName, dictionary MovieMetaData)	-> search subtitle
// string SubtitleDownload(string id)												-> download subtitle

bool isDebug = false;

string HtmlSpecialCharsDecode(string str)
{
	str.replace("&amp;", "&");
	str.replace("&quot;", "\"");
	str.replace("&#039;", "'");
	str.replace("&lt;", "<");
	str.replace("&gt;", ">");
	str.replace("&rsquo;", "'");
	return str;
}

string ZMK_URL = "http://zimuku.la";
string ZMK_DOWNLOAD_URL = "http://zmk.pw";
string HOST_USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.88 Safari/537.36 Edg/87.0.664.66";

array<array<string>> LangTable =
{
	{ "en", "English" },
	{ "zh-TW", "Chinese" },
	{ "zh-CN", "Mandarin" }
};
string GetTitle()
{
	return "字幕库";
}
string GetVersion()
{
	return "0.1";
}
string GetDesc()
{
	return "https://github.com/";
}
string GetLoginTitle()
{
	return "Token";
}
string GetLoginDesc()
{
	return "无需登录";
}
string GetLanguages()
{
	string ret = "";
	for(int i = 0, len = LangTable.size(); i < len; i++)
	{
		string lang = LangTable[i][0];
		
		if (!lang.empty())
		{
			if (ret.empty()) ret = lang;
			else ret = ret + "," + lang;
		}
	}
	return ret;
}	
string ServerCheck(string User, string Pass)
{
	return ServerLogin(User, Pass);
}
string ServerLogin(string User, string Pass)
{
	return "无需登录";
}

string SubtitleWebSearch(string MovieFileName, dictionary MovieMetaData)
{
	// MovieMetaData 示例
	// fileName :   Drawing.Sword.2005.E02.1080p.WEB-DL.H264.AAC-TJUPT
	// fileExtension :   mp4
	// year :   2005
	// formatName :   WEB-DL
	// title :   Drawing Sword
	// seasonNumber :   2
	// audioCodec :   AAC
	// episodeNumber :   0
	// videoEncoder :   H264
	// resolution :   1080p
	// releaseGroup :   TJUPT
	string title = HtmlSpecialCharsDecode(string(MovieMetaData["title"]));
	if (isDebug) {
		HostOpenConsole();
		const array<string> keys = MovieMetaData.getKeys();
		for (uint i = 0; i < keys.size(); i++){
			string key = string(keys[i]);
			HostPrintUTF8(key + " :   " + string(MovieMetaData[key]));
		}
	}
	string finalURL = ZMK_URL + "/search?q=" + HostUrlEncode(title);
	return finalURL;
}

void HtmlRemoveStartToEnd(string &htmlString, string start, string end) 
{
	int nonXmlStart = 0;
	int nonXmlStop = 0;
	int lastIndex = 0;
	// remove start * end
	nonXmlStart = htmlString.findFirst(start);
	lastIndex = nonXmlStart;
	while (nonXmlStart >= 0) {
		nonXmlStop = htmlString.findFirst(end, lastIndex);
		if (nonXmlStop < 0) {
			break;
		}
		htmlString.erase(nonXmlStart, nonXmlStop - nonXmlStart + end.length());
		nonXmlStart = htmlString.findFirst(start, lastIndex);
		lastIndex = nonXmlStart;
	}
}

void HtmlRemoveEndToStart(string &htmlString, string start, string end) 
{
	int nonXmlStart = 0;
	int nonXmlStop = 0;
	int lastIndex = 0;
	// remove start*end
	nonXmlStop = htmlString.findFirst(end);
	while (nonXmlStop > 0) {
		string subString = htmlString.substr(0, nonXmlStop);
		nonXmlStart = subString.findLast(start);
		if (nonXmlStart < 0) {
			break;
		}
		htmlString.erase(nonXmlStart, nonXmlStop - nonXmlStart + end.length());
		nonXmlStop = htmlString.findFirst(end);
	}
}

void Html2Xml(string &htmlString) 
{
	// remove html doctype
	// remove <!--*-->
	HtmlRemoveStartToEnd(htmlString, "<!--", "-->");
	// remove <meta*>
	HtmlRemoveStartToEnd(htmlString, "<meta", ">");
	HtmlRemoveStartToEnd(htmlString, "<img", ">");
	HtmlRemoveStartToEnd(htmlString, "<input", ">");
	HtmlRemoveStartToEnd(htmlString, "<br", ">");
	// remove <script*</script>
	HtmlRemoveStartToEnd(htmlString, "<script", "</script>");
	// remove footer
	HtmlRemoveStartToEnd(htmlString, "<footer", "</footer>");
	// remove head
	HtmlRemoveStartToEnd(htmlString, "<head>", "</head>");
	// remove <*/>
	HtmlRemoveEndToStart(htmlString, "<", "/>");
	htmlString.replace("\n\n", " ");
}

bool HasNameValue(XMLElement &in root, string &in name, string &in value)
{
	XMLAttribute a = root.FindAttribute(name);
	if (a.isValid() && a.asString() == value) {
		return true;
	} else {
		return false;
	}
}

XMLElement GetSubXml(XMLElement &in root, string &in name, string &in value, string &in xmlName = "div")
{
	// scan all div of the layer
	XMLElement currentXml = root;
	while (currentXml.isValid()) {
		if (currentXml.Name() == xmlName && HasNameValue(currentXml, name, value)) {
			return currentXml;
		}
		currentXml = currentXml.NextSiblingElement();
	}

	// scan the next layers
	currentXml = root;
	while (currentXml.isValid()) {
		XMLElement subXml = GetSubXml(currentXml.FirstChildElement(xmlName), name, value);
		if (subXml.Name() == xmlName && HasNameValue(subXml, name, value)) {
			return subXml;
		}
		currentXml = currentXml.NextSiblingElement();
	}
	return root;
}

array<string> GetSubs(XMLElement &in divRoot)
{
	// <div class="item prel clearfix">
	//   <div class="litpic hidden-xs">
	//     <a href="/subs/51099.html" target="_blank">
	array<string> subLinks;
	XMLElement subRoot = GetSubXml(divRoot, "class", "item prel clearfix");
	XMLElement currentXml = subRoot;
	while (currentXml.isValid()) {
		if (currentXml.Name() == "div" && HasNameValue(currentXml, "class", "item prel clearfix")) {
			XMLElement childXml = currentXml.FirstChildElement("div");
			childXml = GetSubXml(childXml, "class", "litpic hidden-xs");
			if (childXml.Name() == "div" && HasNameValue(childXml, "class", "litpic hidden-xs")) {
				XMLElement linkXml = childXml.FirstChildElement("a");
				XMLAttribute link = linkXml.FindAttribute("href");
				if (link.isValid()) {
					subLinks.insertLast(link.asString());
				}
			}
		}
		currentXml = currentXml.NextSiblingElement();
	}
	return subLinks;
}

dictionary GetDetailInfo(XMLElement &in trXml) {
	// <tr class="odd">
	//   <td class="first">
	//     <a href="/detail/146827.html" target="_blank" title="入魔 The.Craft.Legacy.2020.1080p.BluRay.x264.DTS-FGT"><b>入魔 The.Craft.Legacy.2020.1080p.BluRay.x264.DTS-FGT</b></a>
	//     <span class="label label-info">SRT</span>&nbsp;
	dictionary item;
	string detailLink;
	string title;
	string format;
	XMLElement td = GetSubXml(trXml.FirstChildElement("td"), "class", "first", "td");
	XMLElement aXml = td.FirstChildElement("a");
	XMLAttribute link = aXml.FindAttribute("href");
	if (link.isValid()) {
		detailLink = link.asString();
	}
	XMLAttribute t = aXml.FindAttribute("title");
	if (t.isValid()) {
		title = t.asString();
	}
	XMLElement formatSpan = aXml;
	while (formatSpan.isValid() && !(formatSpan.Name() == "span" && HasNameValue(formatSpan, "class", "label label-info"))) {
		formatSpan = formatSpan.NextSiblingElement();
	}
	if (formatSpan.isValid() && formatSpan.Name() == "span" && HasNameValue(formatSpan, "class", "label label-info")) {
		format = formatSpan.asString();
	}

	item["title"] = title;
	item["format"] = format;
	item["url"] = ZMK_URL + detailLink;
	item["id"] = item["url"];
	if (isDebug) {
		const array<string> keys = item.getKeys();
		for (uint i = 0; i < keys.size(); i++){
			HostPrintUTF8(keys[i] + " :   " + string(item[keys[i]]));
		}
	}
	return item;
}

array<dictionary> AccessSubUrl(string &in subUrl)
{
	array<dictionary> items;
	string Url = ZMK_URL + subUrl;
	if (isDebug) {
		HostPrintUTF8(Url);
	}
	string subHtml = HostUrlGetString(Url, HOST_USER_AGENT);
	Html2Xml(subHtml);
	XMLDocument doc;
	if (doc.Parse(subHtml)) {
		XMLElement divRoot = doc.FirstChildElement("html").FirstChildElement("body").FirstChildElement("div");
		// <div class="subs box clearfix">
		//   <table class="table" id="subtb">
		//     <tbody>
		//       <tr class="odd">
		//         <td class="first">
		XMLElement tbDiv = GetSubXml(divRoot, "class", "subs box clearfix");
		XMLElement trRoot = tbDiv.FirstChildElement("table").FirstChildElement("tbody").FirstChildElement("tr");
		while (trRoot.isValid()) {
			if (trRoot.Name() == "tr") {
				items.insertLast(GetDetailInfo(trRoot));
			}
			trRoot = trRoot.NextSiblingElement();
		}
	} else {
		if (isDebug) {
			HostPrintUTF8("parse sub html error!");
		}
	}
	return items;
}

array<dictionary> SubtitleSearch(string MovieFileName, dictionary MovieMetaData)
{
	if (isDebug) {
		HostOpenConsole();
	}

	array<dictionary> ret;

	string finalURL = SubtitleWebSearch(MovieFileName, MovieMetaData);
	string zmkHtml = HostUrlGetString(finalURL, HOST_USER_AGENT);
	HostIncTimeOut(10000);
	Html2Xml(zmkHtml);

	if (isDebug) {
		HostPrintUTF8(finalURL);
	}

	XMLDocument doc;
	if (doc.Parse(zmkHtml)) {
		XMLElement divRoot = doc.FirstChildElement("html").FirstChildElement("body").FirstChildElement("div");
		array<string> subLinks = GetSubs(divRoot);
		for (uint i = 0; i < subLinks.length(); i++) {
			HostIncTimeOut(10000);
			ret.insertAt(ret.length(), AccessSubUrl(subLinks[i]));
		}
	} else {
		if (isDebug) {
			HostPrintUTF8("parse main html error!");
		}
	}

	return ret;
}

dictionary AccessDetailUrl(string &in detailUrl) {
	dictionary detail;
	string downloadUrl;
	string detailHtml = HostUrlGetString(detailUrl, HOST_USER_AGENT, "Connection: keep-alive");
	Html2Xml(detailHtml);
	XMLDocument doc;
	if (doc.Parse(detailHtml)) {
		XMLElement divRoot = doc.FirstChildElement("html").FirstChildElement("body").FirstChildElement("div");
		XMLElement aXml = GetSubXml(divRoot, "class", "lside prel");
		aXml = GetSubXml(aXml, "class", "subinfo clearfix", "ul");
		aXml = GetSubXml(aXml.FirstChildElement("li"), "class", "li dlsub", "li");
		aXml = aXml.FirstChildElement("div");
		aXml = GetSubXml(aXml.FirstChildElement("a"), "id", "down1", "a");
		if (aXml.isValid() && aXml.Name() == "a" && HasNameValue(aXml, "id", "down1")) {
			XMLAttribute link = aXml.FindAttribute("href");
			if (link.isValid()) {
				downloadUrl = link.asString();
			}
		}
		if (downloadUrl.length() > 0) {
			detail["download_page_url"] = downloadUrl;
			string downloadHtml = HostUrlGetString(downloadUrl, HOST_USER_AGENT, "Connection: keep-alive");
			Html2Xml(downloadHtml);
			XMLDocument downloadDoc;
			if (downloadDoc.Parse(downloadHtml)) {
				XMLElement downloadDivRoot = downloadDoc.FirstChildElement("html").FirstChildElement("body").FirstChildElement("main").FirstChildElement("div");
				XMLElement liRoot = GetSubXml(downloadDivRoot, "class", "col-xs-12 col-sm-12");
				liRoot = liRoot.FirstChildElement("table").FirstChildElement("tr").FirstChildElement("td").FirstChildElement("div").FirstChildElement("ul").FirstChildElement("li");
				while (liRoot.isValid() && liRoot.Name() == "li") {
					XMLElement a = liRoot.FirstChildElement("a");
					detail["download_url"] = ZMK_DOWNLOAD_URL + a.asString("href");
					break;
				}
			} else {
				if (isDebug) {
					HostPrintUTF8("parse download html error!");
				}
			}
			// HostCloseHTTP(downloadPtr);
		}
	} else {
		if (isDebug) {
			HostPrintUTF8("parse detail html error!");
		}
	}
	return detail;
}

string SubtitleDownload(string id)
{
	dictionary detail = AccessDetailUrl(id);
	string downloadUrl = string(detail["download_url"]);
	string l = HostUrlGetString(downloadUrl, HOST_USER_AGENT, "Referer: " + string(detail["download_page_url"]));
	return l;
}
