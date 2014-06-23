@my_config = {
	# changer l'adresse du site
	'site_root' => "http://www.afrodeau1.over-blog.com/",

#	'siteKind' => "HautEtFort",
	'siteKind' => "OverBlog",
	# si vous souhaitez transferez vos images completez le lien
	'image_root' => "",
}
def getConfig
	 return @my_config 
end
