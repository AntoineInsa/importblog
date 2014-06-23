require "open-uri"
require "date"

class BlogSite
	attr_reader :site_root, :title, :categories, :image_root
	def initialize(root, image)
		@site_root = root
		@categories = {}
		@image_root = image
		var = readFile("index.html", false)
		@title = var.match(/<title>(.*?)<\/title>/)[1]
		regExpCat = Regexp.compile('href="'+@site_root+'([^/]*?)/">(.*?)</a>')
		var.scan(regExpCat) {|x,title| appendCat(x,title)}
	end

	def appendCat(link, title)
		@categories[link] = title
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
		fileName = url.gsub("/", "_")
		if File.exist?("files/"+fileName) and not force
			$LOG.info "opening: files/"+fileName
			var = open("files/"+fileName).read
		else
			sleep 2
			begin
				$LOG.info "opening: "+@site_root+url
				var = open(@site_root+url).read
				puts "saving..." + fileName
				arch = File.new("files/"+fileName,"w")
				arch.puts var
				arch.close
			rescue 
				puts "Error: page not found"
				var=""
				$LOG.warn "Page not found: #{@site_root+url}"
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
		file = File.new("cat-"+url+".xml","w")
		cat = Category.new(self, title)
		cat.download("archives/category/"+url+".html")
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
	end
	def download(url)
		@links = []
		@titles = []
		@articles = []
		regExpLink = Regexp.compile('<h3 class="total"><a href="'+@site.site_root+'(.*?)">(.*?)</a>')
	var = @site.readFile(url, false)
		if var.match(regExpLink)
			var.scan(regExpLink) {|link, title| appendArticle(link, title)}
		end
		@articles.collect {|a| a.SetCategory(self)}
	end
	def appendArticle(link, title)
		@links << link
		@titles << title
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
		date.scan(/(\d+) +([a-zéû]+) +(\d+)/) {|d,m,y|  @date= y+"-"+getMonth(m)+"-"+d}
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
		if $blog.image_root != ""
			exp= Regexp.new('<img src="'+$blog.site_root+'.*?/([^/]*)".*?/>', true)
			var.gsub!(exp,'<img src="'+$blog.image_root+'\1"/>')
		end if
		foo = var.match(/<h3.*?><span>(.*?)<\/span><\/h3>/)
		@title = foo[1]
		$LOG.info "title: " + @title

		foo = var.match(/<div class="posttext-decorator2">(.*?)(<\/div>\s*)(<\/div>\s*)(<\/div>\s*)<div class="postbottom">/m)
		@message = foo[1]

		foo = var.match(/<h2 class="date"><span>\s*(.*?)\s*<\/span><\/h2>/)
		@date = foo[1]
		@date.scan(/(\d+) +([a-zéû]+) +(\d+)/) {|d,m,y|  @date= y+"-"+getMonth(m)+"-"+d}
		$LOG.debug "date: " + @date

#		var.scan(/<div class="commentparent">.*?<p id="(.*?)"><img .*?\/>(.*?)<\/p>.*?<p class="posted">(.*?)<\/p>.*?((<\/div>.*?<div class="commentchild.*?<\/div>)|(<\/div>))/m) {|id, msg, opt, rsp| self.appendComments(id,msg,opt,rsp) }
		var.scan(/<div class="(commentparent|commentchild).*?<p id="(.*?)"><img .*?\/>(.*?)<\/p>.*?<p class="posted">(.*?)<\/p>.*?<\/div>/m) {|foo,id, msg, opt| self.appendComments(id,msg,opt) }
		if @comments.length() > 0
			$LOG.info "commentaires: " + String(@comments.length())
		end
	end
	def SetCategory(cat)
		@category = cat
		@site = cat.site
	end
	def appendComments(id, msg,opt)
		com = opt.match(/Ecrit par : (.*?) \| .*? (\d+ [a-zéû]+ \d+)/mi)
		if com
			@comments << Comment.new(msg, id, com[1], com[2], "0")
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

