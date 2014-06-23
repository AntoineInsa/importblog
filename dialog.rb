require "fileutils.rb"
require "logger"

def readFromSITE

	config = {}
	site_root = open("SITE_ROOT.txt").readline
	site_root.chomp!
	
	if site_root.match(/http:\/\/your.over-blog.com/)
		puts "Veuillez entrer le nom de votre blog - vous pouvez aussi mettre le nom de votre blog dans le fichier SITE_ROOT.txt"
		site_root = gets
	end
	$LOG.info("Site root: #{site_root}")
	if not site_root.match(/http:\/\/.*?./)
		puts "Erreur de format de votre url : elle doit etre du type http://site.over-blog.org/"
		$LOG.fatal "Erreur de format de votre url : elle doit etre du type http://site.over-blog.org/"
		exit -1
	end
	config['site_root'] = site_root
	config['image_root'] = ""
	config['siteKind'] = "OverBlog"
	return config
end

$LOG = Logger.new("logs",'monthly')

config = {}

if File.exist?("SITE_ROOT.txt")
	$LOG.warn "Old style configuration"
	config = readFromSITE()
else
	require "config.rb"
	config  = getConfig()
end

begin
	FileUtils.mkdir_p "files"

	if not config['site_root'].match(/\/$/)
		config['site_root'] += "/"
	end
	if config['siteKind'] == "OverBlog"
		require "convertOB.rb"
		$LOG.info "Site overblog: " + config['site_root']
	elsif config['siteKind'] == 'HautEtFort'
		require "convertHF.rb"
		$LOG.info "Site Haut et Fort: " + config['site_root']
	else
		$LOG.error "No kind found"
		puts "Puts not managed web site"
		exit -1
	end
	$blog = BlogSite.new(config['site_root'],config['image_root'])
	puts $blog.title

	$blog.getAllCategories()
rescue Exception => e
	$LOG.error "Exception: #{e.inspect} in #{e.backtrace[0]}"
end

$LOG.info "End of script"


