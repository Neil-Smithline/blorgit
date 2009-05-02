class Blog < ActiveFile::Base
  self.base_directory = $blogs_dir
  self.location = ["**", :name, "org"]
  acts_as_org

  # If the git_commit option is set then add a hook to automatically
  # commit any changes from the web interface to git, and push
  if $global_config[:config]['git_commit']
    puts "adding git commit hooks Blog.after_save"
    
    add_hooks(:save)

    def after_save
      Dir.chdir(Blog.base_directory) do
        %x{git add #{self.path} && git commit -a -m "#{self.path} updated through web interface" && git push}
      end
    end
  end

  def self.files(path)
    base = (File.directory?(self.expand(path)) ? self.expand(path) : File.dirname(self.expand(path)))
    self.entries(path).
      map{ |f| File.join(base, f) }.
      select{ |f| (File.directory?(f) or f.match(Blog.location_regexp)) }.
      map{ |f| f.sub(Blog.base_directory, '')}.
      reject{ |f| (f.match(/\/\./) or f.match(/^\./)) }
  end

  def self.search(query)
    # self.all.select{ |b| b.body.match(/#{query}/im) }
    self.all.map{ |b| [b, b.body.split(/#{query}/im).size - 1] }.select{ |blog, hits| hits > 0 }
  end

  def title() ((self.body.match(/^#\+TITLE:[ \t]?(.+?)$/) and $1) or self.name) end
  def comment_section() self.body[$~.end(0)..-1] if self.body.match(/^\* COMMENT Comments$/) end
  def comments() Comment.parse(self.comment_section) end
  def add_comment(comment) self.ensure_comments_section; self.body << comment.raw end
  def commentable() subtree_properties(self.ensure_comments_section)[:commentable] end

  # ensure that the body has one and only one line that looks like
  #
  #    * COMMENT Comments
  #
  # to separate the blog from the comments
  def ensure_comments_section
    if self.body.match(/^\* COMMENT Comments$/)
      self.body[$~.end(0)..-1] = self.body[$~.end(0)..-1].gsub(/^\* COMMENT Comments/, '')
    else
      self.body << "\n* COMMENT Comments\n"
    end
  end

  def subtree_properties(raw)
    props = {}
    raw.split("\n").
      each{ |prop_line| props[$1.intern] = $2.chomp if prop_line.match(/^[ \t]+:(.+):[ \t]+(.*)$/) } if
      raw.match(/^[ \t]+:PROPERTIES:(.*):END:/m)
    props
  end

end
