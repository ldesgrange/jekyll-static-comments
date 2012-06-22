class Jekyll::Site
  attr_accessor :comments

  alias :site_payload_without_comments :site_payload

  def site_payload
    if self.comments
      payload = {
        "site" => { "comments" => self.comments.values.flatten.sort.reverse },
      }.deep_merge(site_payload_without_comments)
    else
      payload = site_payload_without_comments
    end
    payload
  end
end

class Jekyll::Post
  alias :to_liquid_without_comments :to_liquid

  def to_liquid
    data = to_liquid_without_comments
    data['comments'] = StaticComments::find_for_post(self)
    data['comment_count'] = data['comments'].length
    data
  end
end

module StaticComments

  class StaticComment
    include Comparable
    include Jekyll::Convertible

    MATCHER = /^(.+\/)*(\d+-\d+-\d+)-(.*)-([0-9]+)(\.[^.]+)$/

    attr_accessor :site
    attr_accessor :id, :url, :post_title, :date, :author, :email, :link
    attr_accessor :content, :data, :ext, :output

    def initialize(post, comment_file)
      @site = post.site
      @post = post
      self.process(comment_file)
      self.read_yaml('', comment_file)

      if self.data.has_key?('date')
        self.date = Time.parse(self.data["date"])
      end
      if self.data.has_key?('name')
        self.author = self.data["name"]
      end
      if self.data.has_key?('email')
        self.email = self.data["email"]
      end
      if self.data.has_key?('link')
        self.link = self.data["link"]
      end
      self.url = "#{post.url}#comment-#{id}"
      self.post_title = post.slug.split('-').select {|w| w.capitalize! || w }.join(' ')

      payload = {
        "page" => self.to_liquid
      }
      do_layout(payload, {})
    end

    def process(file_name)
      m, cats, date, slug, index, ext = *file_name.match(MATCHER)
      self.date = Time.parse(date)
      self.id = index
      self.ext = ext
    end

    def <=>(other)
      cmp = self.date <=> other.date
      if 0 == cmp
        cmp = self.post.slug <=> other.post.slug
      end
      return cmp
    end

    def to_liquid
      self.data.deep_merge({
        "id" => self.id,
        "url" => self.url,
        "post_title" => self.post_title,
        "date" => self.date,
        "author" => self.author,
        "email" => self.email,
        "link" => self.link,
        "content" => self.content
      })
    end
  end

  def self.find_for_post(post)
    post.site.comments ||= Hash.new
    post.site.comments[post.id] ||= read_comments(post)
  end

  def self.read_comments(post)
    comments = Array.new

    Dir["#{post.site.source}/_comments/#{post.date.strftime('%Y-%m-%d')}-#{post.slug}-*"].sort.each do |comment_file|
      next unless File.file?(comment_file) and File.readable?(comment_file)
      comment = StaticComment.new(post, comment_file)
      comments << comment
    end

    comments
  end
end
