require "open-uri"
require "date"

class BlogSite
	attr_reader :site_root, :title, :categories, :new_site
	def initialize(root, new_site)
		@site_root = root
		@categories = {}
		@new_site = new_site
		var = readFile("index.html", false)
		@title = var.match(/<title>(.*?)<\/title>/)[1]
		regExpCat = Regexp.compile("categorie-(\d+)") 
		var.scan(/categorie-(\d+).html">(.*?)<\/a>/) {|x,title| appendCat(x,title)}
	end

	def appendCat(num, title)
		@categories[num] = title
	end

	def getAllCategories()
		myCategories = []
		for k in @categories
			puts k[1]
			myCategories << getCategory(k[0],k[1])
		end
		file = File.new("TheBigFile.xml","w")
		# all in one big file
		printHeader(file)
		for k in myCategories
			k.printArticles(file)
		end
		printFooter(file)
	end

	def getImage(url)
		name = url.to_s.split("/")[-1]
		if File.exist?("image/"+name)
			return
		end
		puts name
		begin
			var = open(url.to_s).read
			arch = File.new("image/"+name,"wb")
			arch.puts var
			arch.close
		rescue 
			puts "Error: image not found"
			var=""
		end
	end

	def readFile(url, force)
		if File.exist?("files/"+url) and not force
			$LOG.info "opening: files/"+url
			var = open("files/"+url).read
		else
			sleep 2
			begin
				$LOG.info "opening: "+@site_root+url
				var = open(@site_root+url).read
				puts "saving..." + url
				arch = File.new("files/"+url,"w")
				arch.puts var
				arch.close
			rescue 
				$LOG.warn "Page not found: #{@site_root+url}"
				if url.match("-6.")
					url.sub!("-6.","-comments.")
					var = readFile(url, force)
				else
					puts "Error: page not found (" + @site_root+url + ")"
					var=""
				end
			end
		end
		return var
	end

	def printHeader(file)
		file.puts '<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"
	xmlns:content="http://purl.org/rss/1.0/modules/content/"
	xmlns:wfw="http://wellformedweb.org/CommentAPI/"
	xmlns:dc="http://purl.org/dc/elements/1.1/"
	xmlns:wp="http://wordpress.org/export/1.0/"
>

<channel>
	<title>jrcourtois</title>
	<link>http://blog.jrcourtois.net</link>
	<description>Un blog utilisant WordPress</description>
	<pubDate>Sat, 29 Mar 2008 11:24:05 +0000</pubDate>
	<wp:wxr_version>1.1</wp:wxr_version>
	<generator>http://wordpress.org/?v=2.3.3</generator>
	<language>fr</language>'
	end

	def printFooter(file)
		file.puts "</channel></rss>"
	end

	def getCategory(url, title)
		$LOG.info "Category: " + title
		file = File.new("cat-"+title.gsub(/\W/,"")+".xml","w")
		cat = Category.new(self, title)
		cat.download("categorie-"+url+".html")
		printHeader(file)
		cat.printArticles(file)
		printFooter(file)
		return cat
	end

end

class Category
	attr_reader :title, :nicename, :site
	def initialize(_site, _title)
		@site = _site
		@title = _title
		@nicename = @title.gsub(/\W/,"").downcase
		@i=0
	end
	def download(url)
		@links = []
		@titles = []
		@articles = []
		#regExpTitle = Regexp.compile("<title>(.*) - " + @site.title + ".*<\/title>")
		regExpLink = Regexp.compile('<a href="' + @site.site_root + '(article-.*?)" class="titreArticle" title="(.*?)">')
		goon = true
		while goon
			var = @site.readFile(String(@i)+"-" + url, false)
			if var.match(regExpLink)
				var.scan(regExpLink) {|link, title| appendArticle(link, title)}
			else
				goon = false
			end
		end
		regExpLink = Regexp.compile('<a href="' + @site.site_root + '(article-.*?)" class="titreExtrait">(.*?)<')
		goon = true
		while goon
			var = @site.readFile(String(@i)+"-" + url, false)
			if var.match(regExpLink)
				var.scan(regExpLink) {|link, title| appendArticle(link, title)}
			else
				goon = false
			end
		end
		#@title = var.match(regExpTitle)[1]
		@articles.collect {|a| a.SetCategory(self)}
	end
	def appendArticle(link, title)
		@links << link
		@titles << title
		@i += 1
		puts "Getting " + title + " - " + link+ "..."
		@articles << Article.new(link, @site)
	end
	def summary
		print @title
		print @titles.length
	end
	def printArticles(file)
		file.puts '
<wp:category><wp:category_nicename>'+@nicename+'</wp:category_nicename><wp:category_parent></wp:category_parent><wp:cat_name><![CDATA['+@title+']]></wp:cat_name></wp:category>
	'
		@articles.collect{|a| a.printArticle(file)}
	end
end



class Comment
	TODAY = Date.today()
	attr_reader :msg, :num, :author, :site, :date, :ref_id
	def initialize(msg, num, author, date, ref)
		@ref_id = ref
		@msg = msg if msg
		@num = num if num
		@author = "Mister X"
		@site = ""
		if author
			ref = author.match(/\s*(.*)\s*<a.*href="(.*?)".*?>\s*(.*?)\s*<\/a>/mi)
			if ref
				if ref[1] != ""
					@author = ref[1]
				else
					@author = ref[3]
				end
				@site = ref[2]
			else
				@author = author
			end
		end
		@date = ""
		if date
			date.scan(/(\d+)\/(\d+)\/(\d+).*(\d+)\D(\d+)/) {|d,m,y,h,i| @date=y+"-"+m+"-"+d+" "+h+":"+i}
			date.scan(/auj.*(\d+)\D(\d+)/mi) {|h,i| @date=TODAY.to_s()+" "+h+":"+i}
			date.scan(/hier.*(\d+)\D(\d+)/mi) {|h,i| @date=(TODAY-1).to_s()+" "+h+":"+i}
			date.scan(/il y a\s*(\d).*(\d+)\D(\d+)/mi) {|d,h,i| @date=(TODAY-d.to_i()).to_s()+" "+h+":"+i}
		end
		if @ref_id != "0"
			@date += ":30"
		else
			@date += ":00"
		end
	end
	def printComment(file)
		file.puts "<wp:comment>"
		file.puts "<wp:comment_id>" + @num +"</wp:comment_id>"
		file.puts "<wp:comment_author><![CDATA[" + @author + "]]></wp:comment_author>"
		file.puts "<wp:comment_author_email></wp:comment_author_email>"
		file.puts "<wp:comment_author_url>" + @site+ "</wp:comment_author_url>" if @site
		file.puts "<wp:comment_date>" + @date + "</wp:comment_date>"
		file.puts "<wp:comment_content>" + @msg + "</wp:comment_content>"
		file.puts "<wp:comment_approved>1</wp:comment_approved>
		<wp:comment_type></wp:comment_type>
		<wp:comment_parent>"+@ref_id+"</wp:comment_parent>"
		file.puts "</wp:comment>"
	end
end

class Article
	attr_reader :title, :message, :date ,:comments
	def initialize(url, _site)
		@category=""
		@comments = []
		url.sub!(/\./, '-6.')
		@id = url
		@title=""
		@message=""
		@author = "anonyme"
		@date = ""
		var = _site.readFile(url, false)
		if var == ""
			return
		end
		var.gsub!(/=\n/,'=')
		var.gsub!(/<img src="(.*?)">/i,'<img src="\1"/>')
		var.gsub!(/<script type="text\/javascript".*?\<\/script>/m,"")
		foo = var.match(/<div class="divTitreArticle">.*?<h2>.*?<a.*?class="titreArticle"\s*title="(.*?)".*?>\s*(.*?)\s*<\/a>.*?<\/h2>.*?<\/div>(.*)/m)
		@title = foo[2]
		puts "title: " + @title
		suite = foo[3]
		suite.gsub!(/ style\s*=\s*".*?"/, "")
		foo = suite.match(/<div class="contenuArticle">(.*?)<\/div>\s*?<div class="option afterArticle"/m)
		$LOG.info "title: " + @title
		@message = foo[1]

		foo = var.match(/<div class="date">\s*(.*?)\s*<\/div>/m)
		if foo
			@date = foo[1]
			@date.scan(/([A-Za-z]+) +(\d+) +([a-zéû]+) +(\d+)/) {|j,d,m,y|  @date= y+"-"+getMonth(m)+"-"+d}
			$LOG.debug "date: " + @date
		end
		foo= var.match(/<span class="publishedBy">par (.*)<\/span>/)
		if foo
			@author =  foo[1]
		end
		var.scan(/class="commentContainer.*?">\s*<div class="commentMessage">(.*?)<\/div>\s*<div class="commentOption.*?>(.*?)<\/div>(.*?)\s*<\/div>\s*(<a name|<div  id="anchorEndComment" >|<div.*?id="comment)/m) {|msg, opt, rsp| self.appendComments(msg,opt,rsp) }
		if @comments.length() > 0
			$LOG.info "commentaires: " + String(@comments.length())
		end
		# recuperation des images
		if _site.new_site != ""
			@message.scan(/<img src="(.*?)"/) {|url| _site.getImage(url)}
			@message.gsub!(/<img src="(.*?)([^\/]*?)"/, '<img src="'+_site.new_site+'/import/\1"')
		end
	end
	def SetCategory(cat)
		@category = cat
		@site = cat.site
	end
	def appendComments(msg,opt,rsp)
		com = opt.match(/comment.*?(\d+).*?post.*?(par|:)\s*(.*)\s*((le|auj|hier|il)(.*))/mi)
		if com
			@comments << Comment.new(msg, com[1], com[3], com[4], "0")
			# answer
			m = rsp.match(/<div\s+class.+?>\s+(.+?)\s+<\/div>\s+<div\s+class=.+?>(.+?)<\/div>/m)
			if m
				rep = m[2].match(/ponse de\s*(.+?)\s*((le|auj|hier|il)(.*))/mi)
				id = com[1] + "com"
				if rep
					@comments << Comment.new(m[1], id, rep[1], com[4], com[1])
				end
			end
			return
		end

	end
	def printArticle(file)
		if title == ""
			return
		end
		nicetitle = @title.gsub(/\s/,"").downcase()
		file.puts "<item>"
		file.puts "<title><![CDATA[" + @title + "]]></title>"
		file.puts "<link>"+@site.site_root + @id + "</link>"
		file.puts "<dc:creator>" + @author + "</dc:creator>"
		file.puts "<category><![CDATA["+@category.title+"]]></category>"
		file.puts "<category domain='category' nicename='"+@category.nicename+"'><![CDATA["+@category.title+"]]></category>"
		file.puts "<guid isPermalink='false'>"+@site.site_root + @id + "</guid>"
		file.puts "<content:encoded><![CDATA[" + @message + "]]></content:encoded>"
		file.puts "<wp:post_id>"+@id+"</wp:post_id>"
		file.puts "<wp:post_date>" + @date +"</wp:post_date>"
		file.puts "<wp:comment_status>close</wp:comment_status>"
		file.puts "<wp:ping_status>open</wp:ping_status>"
		file.puts "<wp:post_name>" + nicetitle + "</wp:post_name>"
		file.puts "<wp:status>publish</wp:status>
		<wp:post_parent>0</wp:post_parent>
		<wp:menu_order>0</wp:menu_order>
		<wp:post_type>post</wp:post_type>"
		comments.collect {|c| c.printComment(file) }
		file.puts "</item>"
	end
end

def getMonth(date)
	if date =~ /^ja/i then 
		return "01"
	end
	if date =~ /^f/i then return "02" end
	if date =~ /^mar/i then return "03" end
	if date =~ /^av/i then return "04" end 
	if date =~ /^mai/i then return "05" end 
	if date =~ /^juin/i then return "06" end
	if date =~ /^juil/i then return "07" end
	if date =~ /^ao/i then return "08" end
	if date =~ /^se/i then return "09" end
	if date =~ /^oc/i then return "10" end
	if date =~ /^no/i then return "11" end
	if date =~ /^de/i then return "12" end
	return "01"
end

