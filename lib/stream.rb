class Stream
  include MongoMapper::Document
  before_save :update_avatar_settings
  before_destroy :unwatch_avatar

  USER = 1; TREND = 2; KEYWORD = 3;

	AZSET = ("a".."z").to_a + ("A".."Z").to_a + (0..9).to_a
	AZLEN = AZSET.size

  key :sid, String    # mavenn stream id
  key :title, String
  key :config, Hash
  key :_type, String
  key :cache, Hash    # cache config in effect
  key :status, String, :default => "Active"

  # activity as [ {actor, object, action} ]
  def tuples(avatar=nil)
    retval = []

    avatar ||= Avatar.first(:name => self.config[:user])
    points = self.config[:points] || 1
    actor = {:person => avatar.name}

    # There are two kinds of actions - comment and submit
    # The posting link is our object, regardless of the action. 
    # We will NOT aggregate multiple comments for a given object. 
    # For comment action, we will include parent comment if any
    
    comments = avatar.comments.where(:pntx.gte => points)
    comments = comments.sort(:posted_at.desc).limit(25).all
    
    submits = avatar.postings.sort(:posted_at.desc).limit(20).all

    pmap = {nil => {}}
    pids = comments.map {|c| c.pid }
    postings = Posting.all(:pid => {"$in" => pids})
    postings.each {|p| pmap[p.pid] = p.objectify}

    cmap = {}
    cids = comments.map {|c| [c.parent_cid, c.contexts]}.uniq.flatten
    parents = Comment.all(:cid => {"$in" => cids})
    parents.each {|c| cmap[c.cid] = c.threadify}
                        
    combined = interleave_by_posted_at(comments, postings)
    combined.each do |item| 
      object = pmap[item.pid] 
      action = item.actify
      thread = []
      if item.is_a?(Comment)
        item.contexts.push(item.parent_cid).uniq.each do |tcid|
          thread << cmap[tcid]
        end
        action[:meta].update(:thread => thread)
      end
      retval << {:object => object, :action => action, :actor => actor}
    end
    retval
  end

  def interleave_by_posted_at(comments, postings)
    result = []

    while !comments.empty? and !postings.empty? do 
      cm = comments.shift
      ps = postings.shift
      item = if cm and ps 
        cm.posted_at > ps.posted_at ? cm : ps 
      else
        cm || ps
      end
      case item
      when Comment; postings.unshift(ps) if ps
      when Posting; comments.unshift(cm) if cm
      end
      result << item
    end
    result
  end

  def activity
    # only support user comment and submission watch currently 

    avatar = Avatar.where(:name => self.config[:user]).first
    pts = self.config[:points] || 1

    # Items are already entered in reverse chronological order. 
    # Getting them back in natural order is fine.
    comments = avatar.comments.where(:pntx.gte => pts).sort(:$natural).paginate
    postings = avatar.postings.sort(:$natural).limit(20).all
    
    # interleave later
    feed = []
    
    (comments + postings).each do |item|
      feed << item.info
    end
    feed
  end

  def self.preview
    av = Avatar.first(:name => %w(pg patio11 tptacek).shuffle.shift)
    Stream.new.tuples(av)
  end
  
  def self.display(item)
    templ = item[:comment] ? Comment::TEMPLATE : Posting::TEMPLATE
    item.keys.each do |field|
      templ = templ.gsub(/\{\{#{field}\}\}/, item[field].to_s)
    end
    templ
  end
		
	def self.generate_stream_id(len=11)
		(1..len).map {AZSET[rand(AZLEN)]}.join
	end

  def self.invalidate(avatar)
    streams = Stream.all("cache.user" => avatar.name)
    Stream.set({:id => {"$in" => streams.map{|x| x.id}}}, :status => 'Invalid')
    avatar.unwatch(streams.size)
  end

  def update_avatar_settings
    previous = self.cache ? self.cache[:user] :nil
    Avatar.unwatch(previous) if previous
    self.cache[:user] = self.config[:user]
    Avatar.watch(self.cache[:user])
  end

  def unwatch_avatar
    Avatar.unwatch(self.cache[:user])
  end

end
