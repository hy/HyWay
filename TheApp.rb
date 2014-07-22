
# http://stackoverflow.com/questions/936249/stop-tracking-and-ignore-changes-to-a-file-in-git


# Cautionary Note:

# In May 2014, a gem was pulled, leading to: 
#        Could not find jwt-0.1.12 in any of the sources
# !
# !     Failed to install gems via Bundler.
# !

# Explanation of what happened and how to fix: (specify old version in gemfile)
# http://stackoverflow.com/questions/23526673/cannot-push-to-heroku-bundler-fails

# http://www.sitepoint.com/uno-use-sinatra-implement-rest-api/


# TODO List:

# [--] http://www.wooptoot.com/file-upload-with-sinatra
# [--] Pick a consistent http client? 
#      http://www.slideshare.net/HiroshiNakamura/rubyhttp-clients-comparison

# MAILGUN on Heroku with rest-client references: 
# https://github.com/rest-client/rest-client
# https://github.com/worldlywisdom/mazuma/blob/master/modules/mailer.rb
# http://documentation.mailgun.com/quickstart.html#sending-messages


# TrueVault
# TrueVault Ruby adapter: https://github.com/marks/truevault.rb

# TrueVault endpoints will look like: 
# https://api.truevault.com/v1/vaults/<vault_id>/documents/<document_id>

# What we have done so far . . . 

# [--] Go to https://proximity.gimbal.com/developer/transmitters 
# [--] Name first beacon Hy1, factory code: 7NBP-BY85C
# [--] Key to Lat: 37.785525, Lon: -122.397581
# [--] TURN ON BLUETOOTH

# [--] Add a rule at: https://proximity.gimbal.com/developer/rules/new

# [--] More analytics: plot trend, 
# [--] plot intervals (times between events), 
# [--] Add a "____ help(s)(ed) ____ _____" route so folks can discover and then 
#      prototype their own reminder texts . . . 

# [--] Consider ID key to int ne: String ('+17244489427' --> 17244489427)
# [--] Enable and Test broadcast to all caregivers
# [--] Enable and Test broadcast to all patients
# [--] Enable and Test broadcast to everyone
# [--] Enable and Test broadcast to dev's

# [--] Enable a way for parents to invite other parents
# [--] Think of a way for kids to interact in anonymous ways with other kids


###############################################################################
# Ruby Gem Core Requires  --  this first grouping is essential
#   (Deploy-to: Heroku Cedar Stack)
###############################################################################
require 'rubygems' if RUBY_VERSION < '1.9'

require 'sinatra/base'
 require 'erb'

require 'sinatra/graph'

require 'net/http'
require 'uri'
require 'json'
require 'pony'
require 'haml'

require 'httparty'

#require 'rest-client'

require 'aws-sdk'

###############################################################################
# Optional Requires (Not essential for base version)
###############################################################################
# require 'temporals'

# require 'ri_cal'   
# require 'tzinfo'

# If will be needed, Insert these into Gemfile:
# gem 'ri_cal'
# gem 'tzinfo'

# require 'yaml'


###############################################################################
#                 App Skeleton: General Implementation Comments
###############################################################################
#
# Here I do the 'Top-Level' Configuration, Options-Setting, etc.
#
# I enable static, logging, and sessions as Sinatra config. options
# (See http://www.sinatrarb.com/configuration.html re: enable/set)
#
# I am going to use MongoDB to log events, so I also proceed to declare
# all Mongo collections as universal resources at this point to make them
# generally available throughout the app, encouraging a paradigm treating
# them as if they were hooks into a filesystem 
#
# Redis provides fast cache; SendGrid: email; Google API --> calendar access
# 
# I am also going to include the Twilio REST Client for SMS ops and phone ops,
# and so I configure that as well.  Neo4j is included for relationship 
# tracking and management.  
#
# Conventions: 
#   In the params[] hash, capitalized params are auto- or Twilio- generated
#   Lower-case params are ones that I put into the params[] hash via this code
#
###############################################################################

class TheApp < Sinatra::Base
  register Sinatra::Graph

  enable :static, :logging, :sessions
  set :public_folder, File.dirname(__FILE__) + '/static'

  configure :development do
    SITE = 'http://localhost:3000'
    puts '____________CONFIGURING FOR LOCAL SITE: ' + SITE + '____________'
  end
  configure :production do
    SITE = ENV['SITE']
    puts '____________CONFIGURING FOR REMOTE SITE: ' + SITE + '____________'
  end

  @@services_available = {:twitter => false,
                         :graphene => false,
                         :mongo => false,
                         :redis => false,
                         :twilio => false,
                         :google => false,
                         :dropbox => false,
                         :sendgrid => false
  }

  configure do
    begin
      PTS_FOR_BG = 10
      PTS_FOR_INS = 5
      PTS_FOR_CARB = 5
      PTS_FOR_LANTUS = 20
      PTS_BONUS_FOR_LABELS = 5
      PTS_BONUS_FOR_TIMING = 10

      DEFAULT_POINTS = 2
      DEFAULT_SCORE = 0
      DEFAULT_GOAL = 500.0
      DEFAULT_PANIC = 24
      DEFAULT_HI = 300.0
      DEFAULT_LO = 70.0

      ONE_HOUR = 60.0 * 60.0
      ONE_DAY = 24.0 * ONE_HOUR
      ONE_WEEK = 7.0 * ONE_DAY

      puts '[OK!] [1]  Constants Initialized'
    end


    if ENV['TWITTER_CONSUMER_KEY'] && ENV['TWITTER_CONSUMER_SECRET'] && \
       ENV['TWITTER_ACCESS_TOKEN'] && ENV['TWITTER_ACCESS_TOKEN_SECRET']

      begin
        require 'oauth'

        consumer = OAuth::Consumer.new(ENV['TWITTER_CONSUMER_KEY'],
                                       ENV['TWITTER_CONSUMER_SECRET'],
                                       { :site => "http://api.twitter.com",
                                         :scheme => :header })
        token_hash = {:oauth_token => ENV['TWITTER_ACCESS_TOKEN'],
                      :oauth_token_secret => ENV['TWITTER_ACCESS_TOKEN_SECRET']}
        
        $twitter_handle = OAuth::AccessToken.from_hash(consumer, token_hash )
        puts '[OK!] [2.1]  Twitter Oauth Client Configured'

        require 'twitter'

        # Refer to https://github.com/sferik/twitter for usage
        $twitter_client = Twitter::REST::Client.new do |config|
          config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
          config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
          config.access_token        = ENV['TWITTER_ACCESS_TOKEN']
          config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
        end
        puts '[OK!] [2.2]  Twitter REST Client Configured'
        @@services_available[:twitter] = true
      rescue Exception => e; puts "[BAD] Twitter config: #{e.message}"; end
    end

    if ENV['GRAPHENEDB_URL']
      begin
        # NEO4j CONFIG via ENV var set via $ heroku addons:add graphenedb
        # heroku addons:open graphenedb
        # Heroku automatically sets up the GRAPHENEDB_URL environment variable

        uri = URI.parse(ENV['GRAPHENEDB_URL'])
        require 'neography'

        $neo = Neography::Rest.new(ENV["GRAPHENEDB_URL"])

        Neography.configure do |conf|
          conf.server = uri.host
          conf.port = uri.port
          conf.authentication = 'basic'
          conf.username = uri.user
          conf.password = uri.password
        end

        query_results = $neo.execute_query("start n=node(*) return n limit 1")
        puts('[OK!] [3]  Graphene ' + query_results.to_s)
        @@services_available[:graphene] = true

      rescue Exception => e;  puts "[BAD] Neo4j config: #{e.message}";  end
    end

    if ENV['MONGODB_URI']
      begin
        require 'mongo'
        require 'bson'    #Do NOT 'require bson_ext' just put it in Gemfile!

        CN = Mongo::Connection.new
        DB = CN.db

        puts("[OK!] [4]  Mongo Configured-via-URI #{CN.host_port} #{CN.auths}")
        @@services_available[:mongo] = true
      rescue Exception => e;  puts "[BAD] Mongo config(1): #{e.message}";  end
    end

    if ENV['MONGO_URL'] and not ENV['MONGODB_URI']
      begin
        require 'mongo'
        require 'bson'    #Do NOT 'require bson_ext' just put it in Gemfile!
        raise 'MONGO_URL provided, but one of MONGO_PORT, MONGO_USER_ID, or MONGO_PASSWORD is not present' unless ( ENV['MONGO_PORT'] && ENV['MONGO_USER_ID'] && ENV['MONGO_PASSWORD'])

        CN = Mongo::Connection.new(ENV['MONGO_URL'], ENV['MONGO_PORT'])
        DB = CN.db(ENV['MONGO_DB_NAME'])
        auth = DB.authenticate(ENV['MONGO_USER_ID'], ENV['MONGO_PASSWORD'])

        puts("[OK!] [4]  Mongo Connection Configured via separated env vars")
        @@services_available[:mongo] = true
      rescue Exception => e  
        puts "[BAD] Mongo config(2): #{e.message}"
      end
    end

    if ENV['MONGOLAB_URI'] and not ENV['MONGODB_URI'] and not ENV['MONGO_URL']
      # To add mongo Lab to heroku, run: $ heroku addons:add mongolab
      # To check out the settings, run: $ heroku addons:open mongolab
      begin 
        require 'mongo'
        mongo_uri = ENV['MONGOLAB_URI']
        # The following parsing code comes from https://devcenter.heroku.com/articles/mongolab#connecting-to-your-mongodb-instance
        db_name = mongo_uri[%r{/([^/\?]+)(\?|$)}, 1]
        client = Mongo::MongoClient.from_uri(mongo_uri)
        DB = client.db(db_name)
        puts("[OK!] [4]  Mongo Connection Configured via MongoLab environment variable")
        @@services_available[:mongo] = true
      rescue Exception => e 
        puts "[BAD] Mongo config(3): #{e.message}"
      end
    end

    if ENV['MONGOHQ_URL'] and not ENV['MONGOLAB_URI'] and not ENV['MONGODB_URI'] and not ENV['MONGO_URL']
      # This environment variable is set up by using the MongoHQ addon. Run: $ heroku addons:add mongolab
      # To check out the settings, run: $ heroku addons:open mongolab
      # Following https://devcenter.heroku.com/articles/mongohq for setup
      begin
        require 'mongo'
        require 'uri'
        db = URI.parse(ENV['MONGOHQ_URL'])
        db_name = db.path.gsub(/^\//, '')
        db_connection = Mongo::Connection.new(db.host, db.port).db(db_name)
        db_connection.authenticate(db.user, db.password) unless (db.user.nil? || db.user.nil?)
        DB = db_connection
        puts("[OK!] [4]  Mongo Connection Configured via MongoHQ environment variable")
        @@services_available[:mongo] = true
      rescue Exception => e 
        puts "[BAD] Mongo config(3): #{e.message}"
      end
    end

    if ENV['REDISTOGO_URL']
      begin
        # Environment variable is set via $ heroku addons:add redistogo
        require 'hiredis'
        require 'redis'
        uri = URI.parse(ENV['REDISTOGO_URL'])
        REDIS = Redis.new(:host => uri.host, :port => uri.port,
                          :password => uri.password)
        REDIS.set('CacheStatus', "[OK!] [5]  Redis #{uri}")
        @@services_available[:redis] = true
        puts REDIS.get('CacheStatus')
      rescue Exception => e;  puts "[BAD] Redis config: #{e.message}";  end
    end

    if ENV['TWILIO_ACCOUNT_SID'] && ENV['TWILIO_AUTH_TOKEN']
      begin
        require 'twilio-ruby'
        require 'builder'
        $t_client = Twilio::REST::Client.new(
          ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN'] )
        $twilio_account = $t_client.account
        puts "[OK!] [6]  Twilio Configured for: #{$twilio_account.incoming_phone_numbers.list.first.phone_number}"
        @@services_available[:twilio] = true
      rescue Exception => e;  puts "[BAD] Twilio config: #{e.message}";  end
    end

    # Store the calling route in GClient.authorization.state 
    # That way, if we have to redirect to authorize, we know how to get back
    # to where we left off...

    if ENV['GOOGLE_ID'] && ENV['GOOGLE_SECRET']
      begin
        require 'google/api_client'
        options = {:application_name => ENV['APP'],
                   :application_version => ENV['APP_BASE_VERSION']}
        GClient = Google::APIClient.new(options)
        GClient.authorization.client_id = ENV['GOOGLE_ID']
        GClient.authorization.client_secret = ENV['GOOGLE_SECRET']
        GClient.authorization.redirect_uri = SITE + 'oauth2callback'
        GClient.authorization.scope = [ 
          'https://www.googleapis.com/auth/calendar',
          'https://www.googleapis.com/auth/tasks'
        ]
        GClient.authorization.state = 'configuration'

        RedirectURL = GClient.authorization.authorization_uri.to_s
        GCal = GClient.discovered_api('calendar', 'v3')

        puts '[OK!] [7]  Google API Configured with Scope Including:'
        puts GClient.authorization.scope
        @@services_available[:google] = true 

      rescue Exception => e;  puts "[BAD] GoogleAPI config: #{e.message}";  end
    end

# (!!!) remember to include rest-client before using mailgun (!!!)
#
#    if ENV['MAILGUN_API_KEY'] && ENV['MAILGUN_DOMAIN']
#      begin
#        require 'rest-client'
#        require 'multimap'
#        puts 'Config block, mailgun section . . .'
#        puts "https://api:#{ENV['MAILGUN_API_KEY']}"\
#  	  "@api.mailgun.net/v2/samples.mailgun.org/messages"
#  	RestClient.post "https://api:#{ENV['MAILGUN_API_KEY']}"\
#  	  "@#{ENV['MAILGUN_DOMAIN']}",
#  	  :from => 'Mailgun Sandbox <postmaster@sandbox95142.mailgun.org>',
#  	  :to => "sracunas@gmail.com",
#  	  :subject => "Hello",
#  	  :text => "Testing Mailgun awesomness thanks to code from Ben!"
#      puts '[OK!] [8]  Mailgun test email sent (hopefully)'
#      rescue Exception => e;  puts "[BAD] Mailgun test: #{e.message}";  end
#    end 

    # Access tokens from   https://www.dropbox.com/developers/core/start/ruby
    if ENV['DROPBOX_ACCESS_TOKEN']
      begin
        require 'dropbox_sdk'
        $dropbox_handle = DropboxClient.new(ENV['DROPBOX_ACCESS_TOKEN'])
        @@services_available[:dropbox] = true
        puts '[OK!] [9]  Dropbox Client Configured'
      rescue Exception => e; puts "[BAD] Dropbox config: #{e.message}"; end
    end

    if ENV['SENDGRID_USERNAME'] && ENV['SENDGRID_PASSWORD']
      begin
        Pony.options = {
          :via => :smtp,
          :via_options => {
          :address => 'smtp.sendgrid.net',
          :port => '587',
          :domain => 'heroku.com',
          :user_name => ENV['SENDGRID_USERNAME'],
          :password => ENV['SENDGRID_PASSWORD'],
          :authentication => :plain,
          :enable_starttls_auto => true
          }
        }

        puts "[OK!] [8]  SendGrid Options Configured"
        @@services_available[:sendgrid] = true
      rescue Exception => e;  puts "[BAD] SendGrid config: #{e.message}";  end
    end

  end #configure



  #############################################################################
  #                             Sample Analytics
  #############################################################################
  #
  # Plot everyone's BG values in the db so far. 
  # 
  # PLEASE NOTE: This route is Illustrative-Only; not meant
  # to scale . . . 
  #
  #############################################################################
 

  # For Example, to view this graph, nav to: 
  #  http://something-something-number.herokuapp.com/plot/history.svg
  graph "history", :prefix => '/plot' do
    puts who = params['From'].to_s
    puts '  (' + who.class.to_s + ')'
    puts flavor = params['flavor']

    search_clause = { flavor => {'$exists' => true}, 'ID' => params['From'] }

    count = DB['checkins'].find(search_clause).count 
    num_to_skip = (count > 20 ? count-20 : 0)

    cursor = DB['checkins'].find(search_clause).skip(num_to_skip)
    bg_a = Array.new
    cursor.each{ |d|
      bg_a.push(d[flavor])
    }
    line flavor, bg_a
  end


  #############################################################################
  #                            Routing Code Filters
  #############################################################################
  #
  # It's generally safer to use custom helpers explicitly in each route. 
  # (Rather than overuse the default before and after filters. . .)
  #
  # This is especially true since there are many different kinds of routing
  # ops going on: Twilio routes, web routes, etc. and assumptions that are
  # valid for one type of route may be invalid for others . . .  
  #
  # So in the "before" filter, we just print diagnostics & set a timetamp
  # It is worth noting that @var's changed or set in the before filter are
  # available in the routes . . .  
  #
  # A stub for the "after" filter is also included
  # The after filter could possibly also be used to do command bifurcation
  #
  # Before every route, print route diagnostics & set the timetamp
  # Look up user in db.  If not in db, insert them with default params.
  # This will ensure that at least default data will be available for every
  # user, even brand-new ones.  If someone IS brand-new, send disclaimer.
  #
  #############################################################################
  before do
    puts where = 'BEFORE FILTER'
    begin
      print_diagnostics_on_route_entry
      @these_variables_will_be_available_in_all_routes = true
      @now_f = Time.now.to_f

# USUSALLY, (for incoming calls and texts) we will have a valid "From" param
# and onboarding is straightforwardly the correct thing to do
# HOWEVER, for outgoing calls, "From" is . . . the app itself! 

    if ((params['From'] != nil) && (params['From'] != ENV['TWILIO_CALLER_ID']))
      @this_user = DB['people'].find_one('_id' => params['From'])

      if (@this_user == nil)
        onboard_a_brand_new_user 
        @this_user = DB['people'].find_one('_id' => params['From'])
      end #if

      puts @this_user
    end #if params

    rescue Exception => e;  log_exception( e, where );  end
  end

  after do
    puts where = 'AFTER FILTER'
    begin

    rescue Exception => e;  log_exception( e, where );  end
  end


  #############################################################################
  #                            Routing Code Notes
  #############################################################################
  # Some routes must "write" TwiML, which can be done in a number of ways.
  #
  # The cleanest-looking way is via erb, and Builder and raw XML in-line are
  # also options that have their uses.  Please note that these cannot be
  # readily combined -- if there is Builder XML in a route with erb at the
  # end, the erb will take precedence and the earlier functionality is voided
  #
  # In the case of TwiML erb, my convention is to list all of the instance
  # variables referenced in the erb directly before the erb call... this
  # serves as a sort of "parameter list" for the erb that is visible from
  # within the routing code
  #############################################################################

  get '/' do
    '!!!!!!!!!!!!!!!!!!!!!!!! SERVER IS READY !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
  end

  get '/test' do
    'Server is up! '  
  end

  get '/services' do
    response_string = ""
    @@services_available.each do |service, status|
      response_string = response_string + "#{service.to_s} is <b>#{status ? '<font color="blue">up</font>' : '<font color="red">down </font>' } </b><br>"
    end  
    response_string
  end

  post '/set_nh_msg' do
    puts what_we_received = params['cmd']

    DB['nh_msg'].remove()
    DB['nh_msg'].insert({'words' => what_we_received})
    
  end

  get '/nh.*.list*' do
    collection_to_list = (params[:splat][0]).downcase

    if params[:splat][1].include?('.current') then
      scope = { 'Discharge' => ''}
    end

    a = Array.new
    DB[collection_to_list].find(scope).each { |row|
      if row['CCphone'] != '' then
        row['id'] = '+' + row['CCphone'].to_s
        row['search_string'] = 'cardiothorasic ' + row['Surgery'].to_s
        a.push(row)
      end
    }

    @msg_suggest = DB['nh_msg'].find_one()['words']
    @label = collection_to_list.upcase + " LIST:"
    @foo = a

    erb :list
  end     # end get '/*.list' do



## This part starting to work 
## Serve data as CSV file
  get /(?<field_name>\w*)_(?<collection_name>\w*)(?<extension>_as_csv)/ix do 
    first_param = params[:captures][0]
    field_name = first_param
    field_name = "" if first_param == "all"
    collection_name = params[:captures][1]
    cursor = DB[collection_name].find()

    content_type 'application/csv'
    attachment collection_name + ".csv"

    keys = ["heading1", "heading2", "heading3", "heading4"]
    values1 = ["row1", "of1", "CSV1", "data1"] 
    values2 = ["row2", "of2", "CSV2", "data2"] 

    csv_string = CSV.generate do |csv|
        csv << keys

    cursor.each{ |d|
      csv << d.values
    }

    end    
  end


## These may not yet work dunno
  post '/upload_timings' do
    file_data = params[:file].read
    csv_rows  = CSV.parse(file_data, headers: true)

    csv_rows.each do |row|
      DB['noora_timings'].insert( JSON.pretty_generate(row) )
    end
  end


## Work in progress
  get /SendSMSto(?<ph_num>.*)/ do
    puts params['ph_num']
    puts text_to_send = DB['nh_msg'].find_one()['words']
    send_SMS_to( '+17244489427', text_to_send)

#    cursor = DB['noora_tracking'].find({"AttendedFirstClass" => "Yes"})

#    cursor.each{ |d|
#      msg = 'With regards to Patient '+d['PatientName']+' and the issue of '+d['MedicalProblem']+' please do come to 2nd class on '+d['SecondClassDate']
#      send_SMS_to( d['PhoneNumberOfAttender'], msg )
#    }
  end


 get /Call(?<ph_num>.*)/ do
    puts params['ph_num']

    # make a new outgoing call
    @call = $twilio_account.calls.create(
      :from => ENV['TWILIO_CALLER_ID'],
      :to => '+17244489427',
      :url => SITE + '/call-handler',
    )
  end #get Call

  post '/call-handler' do
    what_to_say = DB['nh_msg'].find_one()['words']

    response = Twilio::TwiML::Response.new do |r|
      r.Pause :length => 2 
      r.Say 'Hello', :voice => 'woman'
      r.Pause :length => 1
      r.Say what_to_say, :voice => 'woman'
      r.Play 'http://grass-roots-science.info/VascularContent/Audio/limits.mp3'
    end #response

    response.text do |format|
      format.xml { render :xml => response.text }
    end #do response.text

  end #get call-handler

# PERHAPS SEE:
#  https://www.twilio.com/docs/quickstart/ruby/client/outgoing-calls

  
  post '/awsSNSforvideos' do  
    puts "AWS request.env"
    req_env = request.env
    puts req_env

    if req_env["HTTP_X_AMZ_SNS_MESSAGE_TYPE"] == "SubscriptionConfirmation"
      request.body.rewind
      data = JSON.parse request.body.read
      puts data

      puts "Attempting to send confirmation"
      subscribe_confirm = HTTParty.get data['SubscribeURL']
  
      puts "DONE: Confirmed this endpoint to AWS "
    end #if
      

    if req_env["HTTP_X_AMZ_SNS_MESSAGE_TYPE"] == "UnsubscribeConfirmation"

    end #if


    if req_env["HTTP_X_AMZ_SNS_MESSAGE_TYPE"] == "Notification"
      request.body.rewind
      data = JSON.parse request.body.read
      puts data

      puts DB['AWSnotifications'].insert(data)
    end #if
 
  end


## Quick-and-Simple REST endpoint for Vascular Content development . . . 

  get '/vascular_meta' do
    return_message = {} 

    ## If asked for a chapter, serve that content    
      search_clause = params
      search_command = "DB['vascular_meta'].find(#{search_clause})"

      count = DB['vascular_meta'].find(search_clause).count
      puts "Number of pieces of data to return:" + count.to_s

      if count == 0
        return_message[:data] = [] 
        return_message[:status] = "Very Sorry: #{search_command} found nothing"
      else
        cursor = DB['vascular_meta'].find(search_clause)
        results_a = Array.new
        cursor.each{ |d|
          results_a.push(d)
        }
        return_message[:data] = results_a
        return_message[:status] = "OK!: #{search_command} found #{count} items" 
      end

    return_message.to_json 
  end #get vascular metadata

  get '/all_vascular_meta' do
    return_message = {}

    search_command = "DB['vascular_meta'].find()"

    count = DB['vascular_meta'].find().count
    puts "Number of pieces of data to return:" + count.to_s

    cursor = DB['vascular_meta'].find()
    results_a = Array.new
    cursor.each{ |d|
      results_a.push(d)
    }
    return_message[:data] = results_a
    return_message[:status] = "OK!: #{search_command} found #{count} items"

    return_message.to_json
  end #get all vascular metadata
 

  get '/sushi.json' do
    content_type :json
    return {:sushi => ["Maguro", "Hamachi", "Uni", "Saba", "Ebi", "Sake", "Tai"]}.to_json
  end

  get '/questions.json' do
    content_type :json
    return {:questions => ["Is [your baby] ready to eat?", "How hungry do you think [your baby] is?", "What is telling you [your baby] needs to eat?", "How did you know [your baby] was finished?", "Did [your baby] eat enough at this feed?"]}.to_json
  end

  # Shift to MongoDB when we have the time . . .  
  # Also, think about if we would need to put this into TrueVault, and, 
  #   how much of that would we want to do and when?

  # Three types of data: text, audio, video
  # There will be intro text, and different types of Yes and No  
  # There may be a correct and an incorrect answer (T/F) 

  # Screen Title, then: 
  # Question text, audio clip / video poss.  a
  # Text for the "True" button, text for the "False" button  
  #  Where to go if you got it right (link)
  #  Where to go if you get it wrong (link)

  # For now let us just put something reasonable in json as an example

  get '/example1.json' do

    content_type :json
    return {:question => ["Is there pain and swelling when you move your arm?"], :options => ["True", "False"], :correct_answer => "True", :if_correct_go => "http://serene-forest-4377.herokuapp.com/here", :if_wrong_go => "http://serene-forest-4377.herokuapp.com/there", :tags => ["Arm", "Pain", "Move", "Owies"]}.to_json

  end 


  # For now serve some static content from the default pub folder

  get '/here' do
    send_file File.join(settings.public_folder,'broken_arm.gif')
  end

  get '/there' do
    send_file File.join(settings.public_folder,'looks_broken_but_sprained.jpg')
  end

  get '/TestEO' do
    puts temperature = params['temperature']
    puts proximityRSSI = params['proximityRSSI']
    puts battery = params['battery']
    puts identifier = params['identifier']
  end 

  get '/forgot' do
    puts number = params['To']
    puts "BAD PHONE NUMBER" if number.match(/\+1\d{10}\z/)==nil

    puts msg = 'Can you please pick up the ' + params['What']

    send_SMS_to( params['To'], params['What'] )
  end 

  get '/ouch' do
    send_SMS_to( '+17244489427', 'Ouch mom, too hot!' )
#    send_SMS_to( params['To'], params['What'] )
  end 



  # Let's give whatever we receive in the params to REDIS.set
  get '/redisify' do
    puts 'setting: ' + params['key']
    puts 'to: ' + params['value']
    REDIS.set(params['key'], params['value'])
  end

  # REDIS.get fetches it back. . . 
  get '/getfromredis' do
    puts @value = REDIS.get(params['key'])
  end


  #############################################################################
  #             Other Physical Environment Sensing Examples
  #############################################################################
  #
  # Sensor can detect vibration, magnetic proximity and/or moisture
  #
  #############################################################################

  get '/magswitch_is_opened' do
    puts where = "MAGNETIC SWITCH SENSOR OPENING ROUTE"
    the_time_now = Time.now

    event = {
      'ID' => '+17244489427', 
      'utc' => the_time_now.to_f,
      'flavor' => 'fridge', 
      'fridge' => 1.0, 
      'value_s' => '1.0', 
      'Who' => 'ZergLoaf BlueMeat',
      'When' => the_time_now.strftime("%A %B %d at %I:%M %p"),
      'Where' => where,
      'What' => 'Door Magnet Sensor on fridge opened',
      'Why' => 'Fridge main door opening'
    }
    puts DB['checkins'].insert( event, {:w => 1} )
  end


  get '/magswitch_is_closed' do

  end



  # Vibration sensor currently set at 63 milli-g sensitivity for freezer door

  get '/vibration_sensor_starts_shaking' do
    puts where = "VIBRATION SENSOR STARTS SHAKING ROUTE"
    the_time_now = Time.now

    event = {
      'ID' => '+17244489427', 
      'utc' => the_time_now.to_f,
      'flavor' => 'fridge', 
      'fridge' => 1.0, 
      'value_s' => '1.0', 
      'When' => the_time_now.strftime("%A %B %d at %I:%M %p"),
      'Who' => 'ZergLoaf BlueMeat',
      'Where' => where, 
      'What' => 'Vibration Sensor on top of fridge moved', 
      'Why' => 'Possible freezer door opening'
    }

    puts DB['checkins'].insert( event, {:w => 1} )

  end


  get '/vibration_sensor_stops_shaking' do
    puts "VIBRATION SENSOR STOPS SHAKING ROUTE"

  end




  #############################################################################
  # Voice Route to handle incoming phone call
  #############################################################################
  # Handle an incoming voice-call via TwiML
  #
  #  At the moment this has two main use cases:
  #  [1] Allow a patient to verify their last check in
  #  [2] Avoid worry by making the last time and reading available to family
  #
  #  Accordingly, first we look up the phone number to see who is calling
  #   If they have a patient in the system, we play info for that patient
  #   If they are a patient and have data we speak their last report
  #
  #############################################################################
  get '/voice_request' do
    puts "VOICE REQUEST ROUTE"

    patient_ph_num = patient_ph_num_assoc_wi_caller
    # last_level = last_glucose_lvl_for(patient_ph_num)
    last_level = last_checkin_for(patient_ph_num)

    if (last_level == nil)
      @flavor_text = 'you'
      @number_as_string = 'never '
      @time_of_last_checkin = 'texted in.'
    else
      @number_as_string = last_level['value_s']
      @flavor_text = last_level['flavor']
      interval_in_hours = (Time.now.to_f - last_level['utc']) / ONE_HOUR
      @time_of_last_checkin = speakable_hour_interval_for( interval_in_hours )
    end #if

    speech_text = 'Hello!'
    speech_text += 'Let us see what information we have for you.'
    speech_text += ' The last checkin for'
    speech_text += ' ' 
    speech_text += @flavor_text 
    speech_text += ' ' 
    speech_text += 'was' 
    speech_text += ' ' 
    speech_text += @number_as_string
    speech_text += ' ' 
    speech_text += @time_of_last_checkin
   
    response = Twilio::TwiML::Response.new do |r|
      r.Pause :length => 1
      r.Say speech_text, :voice => 'woman'
      r.Pause :length => 1
      r.Hangup
    end #do response

    response.text do |format|
      format.xml { render :xml => response.text }
    end #do response.text
  end #do get



  #############################################################################
  # EXTERNALLY-TRIGGERED EVENT AND ALARM ROUTES
  #############################################################################
  #
  # Whenever we are to check for alarm triggering, someone will 'ping' us,
  # activating one of the following routes. . .
  #
  # Every ten minutes, check to see if we need to text anybody.
  # We do this by polling the 'textbacks' collection for msgs over 12 min old
  # If we need to send SMS, send them the text and remove the textback request
  #
  #############################################################################

  get '/ten_minute_heartbeat' do
    puts where = 'HEARTBEAT'

    begin
      REDIS.incr('Heartbeats')

      cursor = DB['textbacks'].find()
      cursor.each { |r|
        if ( Time.now.to_f > (60.0 * 12.0 + r['utc']) )
          send_SMS_to( r['ID'], r['msg'] )
          DB['textbacks'].remove({'ID' => r['ID']})
        end #if
      }
    
      h = REDIS.get('Heartbeats')
      puts ".................HEARTBEAT #{h} COMPLETE.........................."

    rescue Exception => e
      msg = 'Could not complete ten minute heartbeat'
      log_exception( e, where )
    end

    Time.now.to_s  # <-- Must return a string for all get req's

  end #do tick


  get '/hourly_ping' do
    puts where = 'HOURLY PING'
    a = Array.new

    begin
      REDIS.incr('HoursOfUptime')

      #DO HOURLY CHECKS HERE

      h = REDIS.get('HoursOfUptime')
      puts "------------------HOURLY PING #{h} COMPLETE ----------------------"

    rescue Exception => e
      msg = 'Could not complete hourly ping'
      log_exception( e, where )
    end

    "One Hour Passes"+a.to_s  # <-- Must return a string for all get req's

  end #do get ping


  get '/daily_refresh' do
    puts where = 'DAILY REFRESH'
    a = Array.new

    begin
     REDIS.incr('DaysOfUptime')

     #DO DAILY UPKEEP TASKS HERE

      d = REDIS.get('DaysOfUptime')
      puts "==================DAILY REFRESH #{d} COMPLETE ===================="

    rescue Exception => e
      msg = 'Could not complete daily refresh'
      log_exception( e, where )
    end

    "One Day Passes"+a.to_s  # <-- Must return a string for all get req's

  end



  #############################################################################
  #                         Google API routes
  #
  # Auth-Per-Transaction example:
  #
  # https://code.google.com/p/google-api-ruby-client/
  #          source/browse/calendar/calendar.rb?repo=samples
  # https://code.google.com/p/google-api-ruby-client/wiki/OAuth2
  #
  # Refresh Token example:
  #
  # http://pastebin.com/cWjqw9A6
  #
  #
  #############################################################################

  get '/insert' do
    puts where = 'ROUTE PATH: ' + request.path_info
    begin
      GClient.authorization.state = request.path_info
      ensure_session_has_GoogleAPI_refresh_token_else_redirect()

      puts cursor = DB['sample'].find({'location' => 'TestLand' })

      insert_into_gcal_from_mongo( cursor )
      GClient.authorization.state = '*route completed*'
    rescue Exception => e;  log_exception( e, where ); end
  end


  get '/quick_add' do
    puts where = 'ROUTE PATH: ' + request.path_info
    begin
      GClient.authorization.state = request.path_info
      ensure_session_has_GoogleAPI_refresh_token_else_redirect()

      puts cursor = DB['sample'].find({'location' => 'TestLand' })

      quick_add_into_gcal_from_mongo( cursor )
      GClient.authorization.state = '*route completed*'
    rescue Exception => e;  log_exception( e, where ); end
  end


  get '/delete_all_APP_events' do
    puts where = 'ROUTE PATH: ' + request.path_info
    begin
      GClient.authorization.state = request.path_info
      ensure_session_has_GoogleAPI_refresh_token_else_redirect()

      page_token = nil

      result = GClient.execute(:api_method => GCal.events.list,
       :parameters => {'calendarId' => 'primary', 'q' => 'APP_gen_event'})
      events = result.data.items
      puts events

      events.each { |e|
        GClient.execute(:api_method => GCal.events.delete,
         :parameters => {'calendarId' => 'primary', 'eventId' => e.id})
        puts 'DELETED EVENT wi. ID=' + e.id
      }
    rescue Exception => e;  log_exception( e, where ); end

  end #delete all APP-generated events


  get '/list' do
    ensure_session_has_GoogleAPI_refresh_token_else_redirect()
    
    calendar = GClient.execute(:api_method => GCal.calendars.get,
                               :parameters => {'calendarId' => 'primary' })

    print JSON.parse( calendar.body )
    return calendar.body
  end


  # Request authorization
  get '/oauth2authorize' do
    puts where = 'ROUTE PATH: ' + request.path_info
    begin

      redirect user_credentials.authorization_uri.to_s, 303
    rescue Exception => e;  log_exception( e, where ); end
  end

  get '/oauth2callback' do
    puts where = 'ROUTE PATH: ' + request.path_info
    begin
      GClient.authorization.code = params[:code]
      results = GClient.authorization.fetch_access_token!
      session[:refresh_token] = results['refresh_token']
      redirect GClient.authorization.state
    rescue Exception => e;  log_exception( e, where ); end
  end



  #############################################################################
  # SMS_request (via Twilio) 
  #############################################################################
  #
  # SMS routing essentially follows a command-line interface interaction model
  #
  # I get the SMS body, sender, and intended recipient (the intended recipient
  # should obviously be this app's own phone number).
  #
  # I first archive the SMS message in the db, regardless of what else is done
  #
  # I then use the command as a route in this app, prefixed by '/c/'
  #
  # At this point, I could just feed the content to the routes... that's a bit
  # dangerous, security-wise, though... so I will prepend with 'c' to keep
  # arbitrary interactions from routing right into the internals of the app!
  #
  # So, all-in-all: add protective wrapper, downcase the message content,
  # remove all of the whitespace from the content, . . .
  # and then prepend with the security tag and forward to the routing
  #
  #############################################################################
  get '/SMS_request' do
    puts where = 'SMS REQUEST ROUTE'
    begin

    the_time_now = Time.now

    puts info_about_this_SMS_to_log_in_db = {
      'Who' => params['From'],
      'utc' => the_time_now.to_f,
      'When' => the_time_now.strftime("%A %B %d at %I:%M %p"),
      'What' => params['Body']
    }
    puts DB['log'].insert(info_about_this_SMS_to_log_in_db, {:w => 1 })

    # w == 1 means SAFE == TRUE
    # can specify at the collection level, op level, and init level

    c_handler = '/c/'+(params['Body']).downcase.gsub(/\s+/, "")

    puts "SINATRA: Will try to use c_handler = "+c_handler
    redirect to(c_handler)

    rescue Exception => e;  log_exception( e, where ); end
  end #do get




  #############################################################################
  # Command routes are defined by their separators
  # Command routes are downcased before they come here, in SMS_request
  #
  # Un-caught routes fall through to default routing
  #
  # Roughly, detect all specific commands first
  # Then, detect more complex phrases
  # Then, detect numerical reporting
  # Finally, fall through to the default route
  # Exceptions can occur in: numerical matching
  # So, there must also be an exception route...
  #############################################################################
  get '/c/' do 
    puts "BLANK SMS ROUTE"
    send_SMS_to( params['From'], 'Received blank SMS, . . .  ?' )
  end #do get

  get '/c/hello*' do
    puts "GREETINGS ROUTE"
    msg = 'Hello, and Welcome!'
    msg += ' (All data sent or received is public domain.)'
    msg += ' Text help to this number if you are new!'
   
    send_SMS_to( params['From'], msg )
  end #do get


  #############################################################################
  # Free-Text Q&A: Questions from patients
  #############################################################################
  get /\/c\/q[:,\s]*(?<question>).*/ix do
    puts "Got a FREETEXT Question to forward!!!"

    q_text = params[:captures][0]

    # Store the question, originating phone number, and overall question ord
    the_time_now = Time.now
    question = {
      'utc' => the_time_now.to_f,
      'Who' => params['From'],
      'What' => q_text,
      'When' => the_time_now.strftime("%A %B %d at %I:%M %p")
    }
    puts DB['questions'].insert( question, {:w => 1} )
    puts q_text


    # Use some method to generate a unique Question ID, ideally just ordinal?
    ordinal = 1
    
    # For now, put in a placeholder at q1 and don't increment it (yet)

    # Also for now, put JOYCE_CELL == Steve_cell
    JOYCE_CELL = '+17244489427'

    fwd_text = 'M'+ordinal.to_s+': '+q_text

    send_SMS_to(JOYCE_CELL, fwd_text)
  end #do get

  #############################################################################
  # Free-Text Q&A: Replies from Joyce
  #############################################################################
  get /\/c\/r(?<replytonum>\d*)[:]+[\s]+(?<replytext>\S.*)/ix do
    puts "Got a FREETEXT Response from Joyce to forward!!!"
    replytonum = params[:captures][0].to_i
    replytext = params[:captures][1].to_s

# Look up the ordinal in the db and send Joyce's reply the right phone num
# description of how to use ordinal as primary key:
#  http://docs.mongodb.org/manual/tutorial/create-an-auto-incrementing-field/
  end #do get


  #############################################################################
  # User Generated Plots
  #############################################################################
  get /\/c\/plot[:,\s]*(?<flavor>\w+)[:,\s]*/ix do 
    flavor = params[:captures][0]
    link = SITE + 'plot/history.svg'
    link += '?' 
    link += 'From=' + CGI::escape( params['From'] )
    link += '&'
    link += 'flavor=' + CGI::escape( flavor.downcase )

    puts "Preparing user-generated plot . . . "

    msg = "Link to your plot: " + link
    send_SMS_to( params['From'], msg )
  end #do get


  #############################################################################
  # User Generated Observations
  #############################################################################
  get /\/c\/(?<act>\S+)[\s]*help(s|ed)[\s]*(?<x>\w+)[\s]*(?<where>@\w+)?/ix do
    act = params[:captures][0]
    x = params[:captures][1]
    puts where = params[:captures][2] ? params[:captures][2].gsub('@','') :'unknown'

    msg = 'Great! We\'ll remember that was helpful, to remind you later...  '
    send_SMS_to( params['From'], msg )
   
    the_time_now = Time.now
    event = {
      'ID' => params['From'], 
      'utc' => the_time_now.to_f,
      'trigger' => x,  
      'act' => act, 
      'Who' => params['From'],
      'Where' => where,
      'What' => act,
      'When' => the_time_now.strftime("%A %B %d at %I:%M %p")
    }
    puts DB['observations'].insert( event, {:w => 1} )
  end #do get


  #############################################################################
  # User Role Setting and Configuration Routes
  #############################################################################
  # Authorize from a patient's phone, to enable a caregiver to get updates.
  # We will use the to-be-Caller's(Caregiver's) number as the key to map
  # to the Patient's phone number, to look up the checkin history... 
  #
  # If we detect a leading '+' then we will +add+ what we expect to be 
  # a parent / guardian phone number to the auth list mapping...
  #
  # We sub out whitespace, parens, .'s and -'s from the entered phone number, 
  # so that (650) 324 - 5687 and 650-324-5687 and 650.324.5687 all work
  #
  # To insert into db, ensure 11 numerical digits, starting with a leading '+1'
  # Since we use auth key as the '_id' save will function as an upsert
  #
  # Question: what if multiple caregivers inserted?  
  #############################################################################
  get /\/c\/\+1?s*[-\.\(]?(\d{3})[-\.\)]*\s*(\d{3})\s*[\.-]*\s*?(\d{4})\z/x do
  puts where = "AUTHORIZE NEW CAREGIVER ROUTE"
  begin
    authorization_string = ''
    params[:captures].each {|match_group| authorization_string += match_group}
    authorization_string= '+1' + authorization_string

    if authorization_string.match(/\+1\d{10}\z/) == nil
      reply_via_SMS( 'Please text, for example: +6505555555 (to add that num)' )
    else
      doc = {
        '_id' => authorization_string, 
        'PatientID' => params['From'],
        'CaregiverID' => authorization_string,
        'utc' => @now_f
      }
      DB['groups'].save(doc) unless authorization_string == params['From']

      DB['people'].update({'_id' => params['From']}, 
                          {'$set' => {'active_patient' => 'yes'}}) 

      reply_via_SMS('You cannot register as your own parent!') if authorization_string == params['From']

      reply_via_SMS( 'You have authorized: ' + authorization_string )
      send_SMS_to( authorization_string, 'Authorized for: '+params['From'] )
    end #if

  rescue Exception => e
    msg = 'Could not complete authorization'
    reply_via_SMS( msg )
    log_exception( e, where )
  end

  end #do authorization


  get /\/c\/\-1?s*[-\.\(]?(\d{3})[-\.\)]*\s*(\d{3})\s*[\.-]*\s*?(\d{4})\z/x do
  puts where = "DE-AUTHORIZE A CAREGIVER ROUTE"
  begin    
    authorization_string = ''
    params[:captures].each {|match_group| authorization_string += match_group}
    authorization_string= '+1' + authorization_string

    if authorization_string.match(/\+1\d{10}\z/) == nil
      reply_via_SMS( 'Please text, for example: -6505555555' )
    else
      DB['groups'].remove({'CaregiverID' => authorization_string}) 

      reply_via_SMS( 'You have de-authorized: ' + authorization_string )
      send_SMS_to( authorization_string, 'De-Authorized for: '+params['From'] )
    end #if

  rescue Exception => e
    msg = 'Could not complete de-authorization'    
    reply_via_SMS( msg )
    log_exception( e, where )
  end

  end #do de-authorization



  #############################################################################
  # USER HELP MENU
  #############################################################################
  #
  # Decide if it's a patient or caregiver who is requesting help and then
  # forward them the approp. content. . .
  #
  #############################################################################
  get /\/c\/(help|instructions)/x do

    p_msg = 'HELP TOPICS: text Checkins, Config, or Feedback for info on each.'

    c_msg = 'info=see settings; low67=low BG threshold at 67; high310=high threshold at 310; goal120=set 7 day goal to 120 pts; week=check stats'

    msg = p_msg
    msg = c_msg if DB['groups'].find_one({'CaregiverID' => params['From']})

    reply_via_SMS( msg )

  end # get help


  get /\/c\/(help)?checkins/x do
    msg_for_patient = 'bg123b = glucose 123 at breakfast; c20d = 20g carbs at dinner; n5L = 5U novolog at lunch; L4 = 4U lantus; score = see points'

    reply_via_SMS( msg_for_patient )
  end # Checkins help


  get /\/c\/(help)?config/x do
    msg_for_patient = '+16505551212 = add caregiver at that ph num; info = check settings'

    reply_via_SMS( msg_for_patient )
  end # Config help


  get /\/c\/(help)?feedback/x do
    msg_for_patient = 'Have unanswered questions or comments? Text/call +1 724 448-9427 and leave a message!'

    reply_via_SMS( msg_for_patient )
  end # Feedback help



  #############################################################################
  # Stop all msgs and take this user out of all of the collections
  # (If either patient or caregiver issues this command, dis-enroll BOTH)
  #############################################################################
  get /\/c\/stop/ do
  puts 'STOP ROUTE'

  begin
    DB['groups'].remove( {"CaregiverID"=>params['From']} )
    DB['groups'].remove( {"PatientID"=>params['From']} )
    DB['people'].remove( {"ID"=>params['From']} )
    msg = 'OK! -- stopping all interactions and dis-enrolling both parties'
    msg +=' (Re-register to re-activate)'
  rescue Exception => e
    msg = 'Could not stop scheduled texts'
    log_exception( e, 'STOP ROUTE' )
  end

    reply_via_SMS( msg )
  end #do resign


  #############################################################################
  # Delete all checkin data for this user in the system
  #############################################################################
  get /\/c\/(delete|clear|clearalldata)/ do
  puts 'DELETE ROUTE'

  begin
    authorization_string = params['From']

    if authorization_string.match(/\+1\d{10}\z/) == nil
      msg = 'Phone Number should be of the form: +16505551234'
    else
      DB['checkins'].remove({'ID' => authorization_string})
      msg = 'Erased checkin history for: '+authorization_string
    end

  rescue Exception => e
    msg = 'Could not delete all checkins'
    log_exception( e, 'DELETE ROUTE' )
  end

    reply_via_SMS( msg )
  end #do reset


  #############################################################################
  # Remove a caregiver from the groups collection to stop notices to them
  #############################################################################
  get /\/c\/resign/ do
  puts 'CAREGIVER RESIGNATION ROUTE'
  begin
    DB['groups'].remove( {"CaregiverID"=>params['From']} )
    msg = 'Stopped your notifications. '
    msg += '(Type: ' + params['From'] + ' from patient phone to re-activate)'
  rescue Exception => e
    msg = 'Could not resign caregiver from updates'
    log_exception( e, 'CAREGIVER RESIGNATION ROUTE' )
  end
    reply_via_SMS( msg )
  end #do resign


  #############################################################################
  # Set a new goal and notify both patient and caregiver
  #############################################################################
  get /\/c\/goal[\s:\.,-=]*?(\d{2,4})\z/ do
  puts "GOAL SETTING ROUTE"
  begin
    goal_f = Float(params[:captures][0])
    ph_num = patient_ph_num_assoc_wi_caller
    doc = {
              'ID' => ph_num,
              'Who' => params['From'],
              'goal' => goal_f,
              'utc' => @now_f
    }
    DB['checkins'].insert(doc)
    msg = 'New 7-day goal of: ' + goal_f.to_s + ' -- Go for it!'

  rescue Exception => e
    msg = 'Could not update goal for '+ ph_num.to_s
    log_exception( e, 'GOAL SETTING ROUTE' )
  end

    reply_via_SMS( msg )
   
    ct_msg = 'New goal of: ' + goal_f.to_s 
    send_SMS_to( ph_num, ct_msg ) if ph_num != params['From']
  end # do goal


  #############################################################################
  # Routes enabling either patient or caregiver to change the various settings 
  #############################################################################
  get /\/c\/(hi)g?h?[\s:\.,-=]*(\d{3})\z/ do
  begin
    key = params[:captures][0]
    puts "SETTINGS ROUTE FOR: " + key
    new_f = Float(params[:captures][1])

    ph_num = patient_ph_num_assoc_wi_caller
    record = DB['people'].find_one({'_id' => ph_num})
    id = record['_id']
    DB['people'].update({'_id' => id},
                        {"$set" => {key => new_f}})
    msg = 'New '+key.to_s+': ' + new_f.to_s + ' mg_per_dL'

  rescue Exception => e
    msg = 'Could not update setting for '+key.to_s
    log_exception( e, 'HI SETTING ROUTE' )
  end

    send_SMS_to( ph_num, msg ) if ph_num != params['From']
    reply_via_SMS( msg )
  end #do hi settings

  get /\/c\/(lo)w?[\s:\.,-=]*(\d{2})\z/ do
  begin
    key = params[:captures][0]
    puts "SETTINGS ROUTE FOR: " + key
    new_f = Float(params[:captures][1])

    ph_num = patient_ph_num_assoc_wi_caller
    record = DB['people'].find_one({'_id' => ph_num})
    id = record['_id']
    DB['people'].update({'_id' => id},
                        {"$set" => {key => new_f}})
    msg = 'New '+key.to_s+': ' + new_f.to_s + ' mg_per_dL'

  rescue Exception => e
    msg = 'Could not update setting for '+key.to_s
    log_exception( e, 'LO SETTING ROUTE' )
  end

    send_SMS_to( ph_num, msg ) if ph_num != params['From']
    reply_via_SMS( msg )
  end #do hi settings

  get /\/c\/age[\s:\.,-=]*(\d{2})\z/ do
  begin
    key = params[:captures][0]
    puts "SETTINGS ROUTE FOR: " + key
    new_f = Float(params[:captures][1])

    ph_num = patient_ph_num_assoc_wi_caller
    record = DB['people'].find_one({'_id' => ph_num})
    id = record['_id']
    DB['people'].update({'_id' => id},
                        {"$set" => {key => new_f}})
    msg = 'New '+key.to_s+': ' + new_f.to_s + ' years'

  rescue Exception => e
    msg = 'Could not update setting for '+key.to_s
    log_exception( e, 'AGE SETTING ROUTE' )
  end

    send_SMS_to( ph_num, msg ) if ph_num != params['From']
    reply_via_SMS( msg )
  end #do hi settings

  get /\/c\/(alarm)[\s:\.,-=]*(\d{1})\z/ do
  begin
    key = params[:captures][0]
    puts "SETTINGS ROUTE FOR: " + key
    new_f = Float(params[:captures][1])

    ph_num = patient_ph_num_assoc_wi_caller
    record = DB['people'].find_one({'_id' => ph_num})
    id = record['_id']
    DB['people'].update({'_id' => id},
                        {"$set" => {'alarm' => new_f}})
    DB['people'].update({'_id' => id},
                        {"$set" => {'timer' => new_f}})
    msg = 'New alarm threshold: ' + new_f.to_s + ' hours.'

  rescue Exception => e
    msg = 'Could not update setting for '+key.to_s
    log_exception( e, 'ALARM SETTING ROUTE' )
  end

    send_SMS_to( ph_num, msg ) if ph_num != params['From']
    reply_via_SMS( msg )
  end #do hi settings



  #############################################################################
  # Status-checking Routes. . .  
  #############################################################################
  get '/c/info' do
    puts "INFO ROUTE"
    patient_ph_num = patient_ph_num_assoc_wi_caller
    info_s = info_for( patient_ph_num )
    reply_via_SMS( info_s )
  end #do get

  get '/c/score' do
    puts "SCORE REPORT ROUTE"
    patient_ph_num = patient_ph_num_assoc_wi_caller
    score_s = score_for( patient_ph_num )
    reply_via_SMS( score_s )
  end #do get

  get /\/c\/(recent|week|weekly|history)/ do
    puts "WEEKLY REPORTING ROUTE"
    patient_ph_num = patient_ph_num_assoc_wi_caller
    summary = weekly_summary_for( patient_ph_num ) 
    reply_via_SMS(summary)
  end #do get

  get /\/c\/(check|last|latest)/ do
    puts "LAST CHECKIN ROUTE"

    patient_ph_num = patient_ph_num_assoc_wi_caller
    last_level = last_glucose_lvl_for(patient_ph_num)

    msg = 'Glucose: '
    if (last_level == nil)
      msg += 'not yet reported (no checkins yet)'
      @number_as_string = 'not yet '
      @time_of_last_checkin = 'reported. '
    else
      @level = last_level['mg']
      interval_in_hours = (Time.now.to_f - last_level['utc']) / ONE_HOUR
      @time_of_last_checkin = speakable_hour_interval_for( interval_in_hours )
      msg += @level.to_s
      msg += ' - '
      msg += @time_of_last_checkin
    end #if

    reply_via_SMS(msg)
  end #do get


  #############################################################################
  # "Backspace" over previous Check-In
  #############################################################################
  #
  # In case the user has made a typo and catches the error from the
  # confirmation text, we supply a mechanism to delete the typo in the db
  #
  # Text in "no!" to delete the last checkin 
  #
  #############################################################################
  get /\/c\/(no!|oops!|wrong!|argh!)/ do
    puts where = 'TYPO DELETION ROUTE'

    begin

      delete_last_checkin()

    rescue Exception => e
      reply_via_SMS('SMS not quite right for typo deletion:'+params['Body'])
      log_exception(e, where)
    end

  end #do get


  #############################################################################
  # Revise Check-In
  #############################################################################
  #
  # In case the user has made a typo and catches the error from the 
  # confirmation text, we supply a mechanism to correct the typo in the db
  #
  # Type "!123!" to revise the last checkin to read "123" instead of what
  # was orginally entered... 
  #
  # So if a user types '!123!' in an SMS, we keep the same tags, timestamp
  # etc. and just update the glucose lvl value to '123' 
  #
  #############################################################################
  get /\/c\/!(?<whole>\d*)\.?(?<fraction>\d{0,9})?!/ do |whole,fraction|
    puts where = 'TYPO CORRECTION ROUTE'

    begin
      new_value = whole 

      if (fraction.length >= 1)
        new_value += '.'
        new_value += fraction
      end #if

      revise_last_checkin_to(new_value)

    rescue Exception => e
      reply_via_SMS('SMS not quite right for typo correction:'+params['Body'])
      log_exception(e, where)
    end

  end #do get


  #############################################################################
  # Receive pulse checkin (precision-regex method)
  #############################################################################
  get /\/c\/p(ulse)?[:,\s]*(?<is>\d{2,3})/ix do
    puts where = 'PULSE CHECKIN REGEX ROUTE'

    begin
      pulse_f = Float(params[:captures][0])

      handle_checkin(pulse_f, "pulse")

    rescue Exception => e
      reply_via_SMS('SMS not quite right for a pulse checkin:'+params['Body'])
      log_exception(e, where)
    end

  end #do checkin


  #############################################################################
  # Receive fast-acting insulin checkin (precision-regex method)
  #############################################################################
  get /\/c\/(?<i>n|h)[,\s:]*(?<is>\d*\.?\d+)[,\s:\.]*(?<at>\D*)/ix do
    puts where = 'FAST-ACTING INSULIN CHECKIN REGEX ROUTE'
    
    begin
      insulin_type_s = params[:captures][0]
      amount_taken_s = params[:captures][1]
      when_taken_s = params[:captures][2]

      units_f = Float( amount_taken_s )
      handle_insulin_checkin( units_f, when_taken_s, insulin_type_s )

    rescue Exception => e
      reply_via_SMS('SMS not quite right for insulin checkin:'+params['Body'])
      log_exception(e, where)
    end

  end #do insulin checkin


  #############################################################################
  # Receive long-acting (overnight) insulin checkin (precision-regex method)
  #############################################################################
  get /\/c\/(?<i>l)[,\s:]*(?<is>\d*\.?\d+)[,\s:\.]*(?<at>\D*)/ix do
    puts where = 'LANTUS (LONG-ACTING INSULIN) CHECKIN REGEX ROUTE'
    
    begin
      puts insulin_type_s = params[:captures][0]
      puts amount_taken_s = params[:captures][1]
      puts when_taken_s = params[:captures][2]

      units_f = Float( amount_taken_s )
      handle_lantus_checkin( units_f, when_taken_s)

    rescue Exception => e
      reply_via_SMS('SMS not quite right for a Lantus checkin:'+params['Body'])
      log_exception(e, where)
    end

  end #do insulin checkin


  #############################################################################
  # Receive blood sugar checkin (precision-regex method)
  #############################################################################
  get /\/c\/(mg|b)?g?(lucose)?[:,\s]*(?<is>\d{2,3})[:,\s]*(?<at>\D*)\z/ix do
    puts where = 'BLOOD SUGAR CHECKIN REGEX ROUTE'

    begin
      blood_sugar_f = Float(params[:captures][0])
      checkpoint_s = params[:captures][1]

      # reset_alarm_timer_for( params['From'] )
      handle_glucose_checkin(blood_sugar_f, checkpoint_s)

    rescue Exception => e
      reply_via_SMS('SMS not quite right for a bg checkin:'+params['Body'])
      log_exception(e, where)
    end

  end #do sugar checkin


  #############################################################################
  # Receive carb checkin (precision-regex method)
  #############################################################################
  get /\/c\/c(arb)?s?[,\s:]*(?<is>\d*\.?\d+)[,\s:\.]*(?<at>\D*)/ix do
    puts where = 'CARB CHECKIN REGEX ROUTE'

    begin
      amount_taken_s = params[:captures][0]
      when_taken_s = params[:captures][1]

      grams_f = Float( amount_taken_s )
      handle_carb_checkin( grams_f, when_taken_s )

    rescue Exception => e
      reply_via_SMS('SMS not quite right for a carb checkin:'+params['Body'])
      log_exception(e, where)
    end

  end #do carb checkin


  #############################################################################
  # Reply to a specific index (Survey Question or Forwarded text msg)
  #
  # 
  #
  #
  #############################################################################
  get /\/c\/(?<questionNum>\d+)[\s]*:[\s]*(?<answerText>\D*)/ix do
    questionNum = params[:captures][0]
    answerText = params[:captures][1]

    the_time_now = Time.now

    puts "num = " + questionNum
    puts "text = " + answerText

    # now put the number, the caller ID, and the text into the db . . . 
    # because the reply (to a survey) is specific to the caller, 
    # and the number of the question as well
    # ALSO store the timestamp, in case the questions change with time, 
    # numerically, and/or in case it's possible to answer the same 
    # question multiple times.  And, for the heck of it, store the
    # question itself (as currently phrased) as well :)  

    response = {
      'questionNum' => questionNum,
    # 'Question' => ????????????
      'answerText' => answerText,
      'ID' => params['From'],
      'utc' => the_time_now.to_f,
      'When' => the_time_now.strftime("%A %B %d at %I:%M %p"),
      'Where' => 'here',
      'What' => answerText,
      'Why' => questionNum
    }
    puts DB['responses'].insert( response, {:w => 1} )
  end


  #############################################################################
  # Send email report . . . 
  #############################################################################
  get /(?<email_addy>[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4})/ix do
  puts where = 'GMAIL REGEX ROUTE'
  begin
    puts @email_to = params[:captures][0]
    puts @subject = 'CTSA TEST!' 


    register_email_in_db(@email_to)

    ph = patient_ph_num_assoc_wi_caller
    @data = DB['checkins'].find({'ID'=>ph}).limit(10)

    puts @words = "Last %d check-ins. . . \n" % @data.count
    
    @data.each { |hash|
      hash.delete('_id')
      hash.delete('ID')
      hash.delete('utc')
      @words += hash.inspect
      @words += "\n"
    }

    @body = @words

    Pony.mail(:to => @email_to, :via => :smtp, :via_options => {
      :address => 'smtp.gmail.com',
      :port => '587',
      :enable_starttls_auto => true,
      :user_name => ENV['APP_EMAIL_ADDY'],
      :password => ENV['APP_EMAIL_AUTH'],
      :authentication => :plain, # :plain, :login, :cram_md5, no auth by default
      :domain => "gmail.com",
    },
      :subject => @subject, :body => @body)

    reply_via_SMS('Email sent')

  rescue Exception => e
    reply_via_SMS('Gmail failed')
    log_exception(e, where)
  end

  end #do gmail


  #############################################################################
  # Final / "Trap" routes: 
  #
  # Also:  Of course, if we do not know what the user meant, we should tell 
  # them we could not understand their text message.  
  # 
  #############################################################################


  # Trap+log a string key + digits + tag checkins we didn't anticipate . . .

  get /\/c\/(?<flavor>\D+)[:,\s]*(?<value>\d*\.?\d+)[:,\s]*(?<tag>\S+)/ix do
    flavor_s = params[:captures][0]
    value_f = Float( params[:captures][1] )
    tag_s = params[:captures][2]

    handle_tagged_checkin(value_f, flavor_s, tag_s)
  end #do get

  # Trap+log a string key + float or digit checkins we didn't anticipate . . . 

  get /\/c\/(?<flavor>\D+)[:,\s]*(?<value>\d*\.?\d+)/ix do
    flavor_s = params[:captures][0]
    value_f = Float( params[:captures][1] )

    puts "Logging a checkin of arbitrary / unknown type . . . "

    handle_checkin(value_f, flavor_s)
  end #do get



  get '/c/*' do |text|
    puts 'SMS CATCH-ALL ROUTE'
    reply_via_SMS('Sorry :/ I could not understand that. Maybe check your card or text the word HELP? Also for some commands the exact #of digits is the key')
    doc = {
      'Who' => params['From'],
      'What' => text, 
      'utc' => Time.now.to_f
    }
    DB['unrouted'].insert(doc)
  end #do get


  get '/*' do |text|
    puts 'UNIVERSAL CATCH-ALL FOR ALL UNROUTED USER GETs'
    doc = {
      'Who' => params['From'],
      'What' => text,
      'utc' => Time.now.to_f
    }
    DB['unexpected'].insert(doc)
  end #do get


  post '/*' do |text|
    puts 'UNIVERSAL CATCH-ALL FOR ALL UNROUTED USER POSTs'
    doc = {
      'Who' => params['From'],
      'What' => text,
      'utc' => Time.now.to_f
    }
    DB['unexpected'].insert(doc)
  end #do get

  #############################################################################
  #                  END OF THE ROUTING SECTION OF THE APP                    #
  #############################################################################



  #############################################################################
  # SMS Command routes are defined by their separators
  # Command routes are downcased before they come here, in SMS_request
  # Spaces are optional in SMS commands, and are removed before /c/ routing
  #
  # Un-caught routes fall through to default routing
  #
  # Roughly, detect all specific commands first
  # Then, detect more complex phrases
  # Then, detect numerical reporting
  # Finally, fall through to the default route
  # Exceptions can occur in: numerical matching
  # So, there must also be an exception route...
  #############################################################################



  #############################################################################
  # Helpers
  #############################################################################
  # Note: helpers are executed in the same context as routes and views
  # Note: helpers have the params[] hash available to them in this scope
  #       So, this gives us another option to send reply SMS, in addition
  #       to via-erb... etc.
  #
  # Primarily, I am using helpers as db-accessors and Twilio REST call
  # convenience functions.  Other uses include caller authenitcation or
  # caller blocking, and printing diagnostics, logging info, etc. 
  #
  #############################################################################
  helpers do

    def timestamp()
      Time.now.to_f.to_s
    end

    ###########################################################################
    # View Helpers
    ###########################################################################

    # Got time format strings from Ruby Cookbook p99
    # TO DO: adjust thresholds based on trials... set to 100 for now

    def timeStringFromTimestampString(tss)
      time_diff = Time.now.to_f - tss.to_f
      if time_diff < 100 then
        return Time.at(tss.to_f).strftime("%r")
      elsif time_diff < 101
        return Time.at(tss.to_f).strftime("%a %p")
      else
        return Time.at(tss.to_f).strftime("%a %l:%M%p %x")
      end #if
    end

    ###########################################################################
    # HTML injection: conditional display
    ###########################################################################
    def ifPresentThenShow(hash, key)
      if hash[key]!=hash.default then 
        return beginHTMLstyle(key, hash[key]) + 
               " #{hash[key]} " + endHTMLstyle(key)  
      else
        return " "  # DON'T return nil !!
      end
    end
    def showTextOrHighlight(hash)
      if hash['highlight']!=hash.default then
        return beginHTMLstyle('highlight', hash['highlight']) + 
               hash['highlight'] + " " + endHTMLstyle('highlight')
      elsif hash['text']!=hash.default then
        return beginHTMLstyle('text', hash['text']) + 
               hash['text'] + " " + endHTMLstyle('text')
      else
        return " " # DON'T return nil !!
      end
    end

    ###########################################################################
    # HTML injection: begin and end item HTML style options by hash key
    #
    # Defaults to setting the id of a <span> tag... maybe move all of this
    # functionality into CSS via <span> 's  ?  
    ###########################################################################
    def beginHTMLstyle(key, value)
      return '<font style="color: #28C;">' if key=='_id'
      return '<a href="' + value + '">' if key=='url'
      return '<span class="'+key+'">' 
    end
    def endHTMLstyle(key)
      return '</font>' if key=='_id'
      return '</a>' if key=='url'
      return '</span>'
    end
    ###########################################################################
    # HTML injection: phone the number associated with this row
    ###########################################################################
    def addPhone(row)
      if row['Callable']=='yes' then
        return '<a href="' +SITE+ 'Call?ph=' + row['id'].to_s + '" >
          <img border="0" alt="Phone" src="images/phone.png" /> </a>'
      else
        return ''
      end
    end
    ###########################################################################
    # HTML injection: SMS the number associated with this row
    ###########################################################################
    def addSMS(row)
      if row['SMSable']=='yes' then
        return '<a href="' +SITE+ 'SendSMSto?ph=' + row['id'].to_s + '" >
          <img border="0" alt="SMS" src="images/SMS.png" /> </a>'
      else
        return ''
      end
    end
    ###########################################################################
    # HTML injection: URLs from Co-browsed Tabs
    ###########################################################################
    def addTabList(row)
      return '' if (row['with']==NIL)
      s = ' <h3> Tab Cluster: </h3> <ol>'
      row['with'].each { |t|
        s += '<li>'
        s += '<a href="'+t+'" >' + t + '</a></li>'
      } 
      s += '</ol>'
    end
    ###########################################################################
    # HTML injection: Supported / Contradicted indicator
    ###########################################################################
    def addFace(row)
      if row['HappyFace']=='yes' then
        return '<a href="' +SITE+ 'SadFace?id=' + row['id'].to_s + '" >
          <img border="0" alt="Contradicted" src="images/doh.png" /> </a>'
      elsif row['SadFace']=='yes' then
        return '<a href="' +SITE+ 'HappyFace?id=' + row['id'].to_s + '" >
          <img border="0" alt="Supported" src="images/yay.png" /> </a>'
      else return '<a href="' +SITE+ 'DoNothing?id=' + row['id'].to_s + '" >
          <img border="0" alt="Nothing" src="images/background.png" /> </a>'
      end
    end
    ###########################################################################
    # HTML injection: Checked / unchecked indicator
    ###########################################################################
    def addCircle(row)
      if row['checked']=='yes' then
        return '<a href="' +SITE+ 'UnCheck?id=' + row['id'].to_s + '" >
          <img border="0" alt="Checked" src="images/check.png" /> </a>'
      elsif row['checked']=='no' then
        return '<a href="' +SITE+ 'Check?id=' + row['id'].to_s + '" >
          <img border="0" alt="Supported" src="images/blank.png" /> </a>'
      else 
        return '<a href="' +SITE+ 'UnCheck?id=' + row['id'].to_s + '" >
          <img border="0" alt="Supported" src="images/background.png" /> </a>'
      end
    end
    ###########################################################################
    # HTML injection: Lit or unlit bulb indicates active vs. inactive item
    ###########################################################################
    def addStatusBulb(row)
      if row['On']=='yes' then
        return '<a href="' +SITE+ 'TurnOff?id=' + row['id'].to_s + '" >
          <img border="0" alt="Active" src="images/lit_bulb.png" /> </a>'
      else
        return '<a href="' +SITE+ 'TurnOn?id=' + row['id'].to_s + '" >
          <img border="0" alt="Active" src="images/dark_bulb.png" /> </a>'
      end
    end
    ###########################################################################
    # HTML injection: link to Gmail controller
    ###########################################################################
    def addGmailLink()
      '<a href="' +SITE+ '/gmail">' + 
         '<img border="0" alt="gmail" src="images/gmail.png" /> </a>'
    end
    ###########################################################################
    # HTML injection: link to PubMed
    ###########################################################################
    def addPubMedLink(string)
      return '' if string==nil 
      '<a href="http://www.ncbi.nlm.nih.gov/sites/entrez?cmd=PureSearch&db=pubmed&term=' + string.sub(' ','%2B') + '" >
      <img border="0" alt="PubMed" src="images/PubMed.png" /> </a>'
    end
    ###########################################################################
    # HTML injection: specific document in knowledge base
    ###########################################################################
    def addMongoLink(mongo_collection, row) 
      '<a href="https://mongohq.com/databases/latest/collections/' + 
       mongo_collection + 
      '/documents/' + row['_id'].to_s + '" >  
          <img border="0" alt="MongoHQ" src="images/MongoHQ.png" /> </a>'
    end
    ###########################################################################
    # HTML injection: specific document details from mongo, via HyLiter
    ###########################################################################
    def addDetailLink(row)
      '<a href="' +SITE+ 'note=' +
      row['id'].to_s + '" >  
         <img border="0" alt="Details" src="images/magnify.png" /> </a>'
    end
    ###########################################################################
    # HTML injection: Google-search the text of this row...
    ###########################################################################
    def addGoogleLink(search_string)
      return '' if search_string==nil
      '<a href="http://www.google.com/#hl=en&q=' +
      search_string.sub(' ','+') + '" >
         <img border="0" alt="Google" src="images/google.png" /> </a>'
    end
    ###########################################################################
    # HTML injection: Check wikipedia with the text of this row...
    ###########################################################################
    def addWikipediaLink(search_string)
      return '' if search_string==nil
      '<a href="http://www.google.com/#q=' + search_string.sub(' ','+') + 
      '&oi=navquery_searchbox&sa=X&as_sitesearch=wikipedia.org&hl=en" >
        <img border="0" alt="Google" src="images/wikipedia.png" /> </a>'
    end



    ###########################################################################
    # Logging Helpers
    ###########################################################################
    def log_exception( e, where = 'unspecified' )
      begin
        puts ' --> LOGGING AN EXCEPTION FROM: --> ' + where
        puts e.message
        puts e.backtrace.inspect

        current_time = Time.now
        doc = {
               'Who' => params['From'],
               'What' => e.message,
               'When' => current_time.strftime("%A %B %d at %I:%M %p"),
               'Where' => where,
               'Why' => request.url,
               'How' => e.backtrace,
               'utc' => current_time.to_f
        }
        DB['exceptions'].insert(doc)

      rescue Exception => e
        puts 'ERROR IN ERROR LOGGING HELPER'
        puts e.message
        puts e.backtrace.inspect
      end

    end #def log_exception



    ###########################################################################
    # SECTION: Generic Sinatra Helpers
    ###########################################################################

    ###########################################################################
    # Define a handler for multiple http verbs at once (can be convenient!)
    ###########################################################################
    def any(url, verbs = %w(get post put delete), &block)
      verbs.each do |verb|
        send(verb, url, &block)
      end
    end


    ###########################################################################
    # Helper: Print Route Info Upon Entry (usu. called from the before filter) 
    ###########################################################################
    def print_diagnostics_on_route_entry
      # for the full url: puts request.url
      # for printing part of the url: puts request.fullpath
      # for printing just the path info: puts request.path_info

      puts 'TRYING ROUTE: '+ request.path_info 
      puts ' WITH PARAMS HASH:'
      params.each { |k, v| 
        puts request.path_info + ': ' + k.to_s + ' <---> ' + v.to_s
      }
    end #def


    ###########################################################################
    # SECTION: Google API Helpers
    ###########################################################################

    ###########################################################################
    # Helper: Google API Refresh Token
    ###########################################################################
    def ensure_session_has_GoogleAPI_refresh_token_else_redirect()
      puts where = 'HELPER: ' + (__method__).to_s 
      begin
        redirect RedirectURL unless session[:refresh_token] 
        redirect RedirectURL if session[:refresh_token].length <= 3

        GClient.authorization.refresh_token = session[:refresh_token]
        GClient.authorization.fetch_access_token!
      rescue Exception => e;  log_exception( e, where ); end
    end #ensure_session_has_GoogleAPI_refresh_token_else_redirect()


    ###########################################################################
    # Helper: Google Calendar API Single-Event Insert
    ###########################################################################
    def insert_into_gcal( j )
      puts where = 'HELPER: ' + (__method__).to_s
      begin
        result = GClient.execute(:api_method => GCal.events.insert,
         :parameters => {'calendarId' => 'primary'},
         :body => JSON.dump( j ),
         :headers => {'Content-Type' => 'application/json'})
        puts "INSERTED event with id:" + result.data.id

        return result
      rescue Exception => e;  log_exception( e, where ); end
    end #insert_calendar_event


    ###########################################################################
    # Helper: Google Calendar API Multi-Event Insert from Mongo Cursor
    ###########################################################################
    def insert_into_gcal_from_mongo( cursor )
      puts where = 'HELPER: ' + (__method__).to_s
      begin
        cursor.each { |event|
          result = GClient.execute(:api_method => GCal.events.insert,
           :parameters => {'calendarId' => 'primary'},
           :body_object => event,
           :headers => {'Content-Type' => 'application/json'})
          puts "INSERTED event with result data id:" + result.data.id
        }
      rescue Exception => e;  log_exception( e, where ); end
    end #insert_calendar_event


    ###########################################################################
    # Helper: Google Calendar API Multi-Event Insert from Mongo Cursor
    ###########################################################################
    def insert_bg_checkins_into_gcal_from_mongo( cursor )
      puts where = 'HELPER: ' + (__method__).to_s
      begin
        cursor = DB['checkins'].find({'mg' => {'$exists' => true} })
        cursor.each { |checkin|
        event = Hash.new
        event['summary'] = (checkin['mg']).to_s
        event['color'] = Float(checkin['mg']) < 70 ?  2 : 3
        event['start']['dateTime'] = Time.at(checkin['utc']).strftime("%FT%T%z")
        event['start']['timeZone'] = 'America/Los_Angeles'
        event['end']['dateTime'] = Time.at(checkin['utc']+9).strftime("%FT%T%z")
        event['end']['timeZone'] = 'America/Los_Angeles'

        result = GClient.execute(:api_method => GCal.events.insert,
         :parameters => {'calendarId' => 'primary'},
         :body_object => event,
         :headers => {'Content-Type' => 'application/json'})
        puts "INSERTED event with result data id:" + result.data.id
        }
      rescue Exception => e;  log_exception( e, where ); end
    end #insert_calendar_event


    ###########################################################################
    # SECTION: Speakbles
    ###########################################################################

    ###########################################################################
    # Helper: Speakble Time (usage: speakable_time_for( Time.now )
    ###########################################################################
    def speakable_time_for( time )
      puts where = 'HELPER: ' + (__method__).to_s

      return time.strftime("%A %B %d at %I:%M %p")
    end #def

    ###########################################################################
    # Helper: Speakable Time Interval given float (and optional preamble)
    ###########################################################################
    def speakable_hour_interval_for( preamble=' ', float_representing_hours )
      puts where = 'HELPER: ' + (__method__).to_s
      begin
        msg_start = preamble

        whole_hours_i = float_representing_hours.to_i

        msg_start += whole_hours_i.to_s unless whole_hours_i==0

        h_f = float_representing_hours.floor
        h = float_representing_hours - h_f

        msg_mid = if    (h_f<=0)&&(h <= 0.2) then ' just a little while'
                  elsif (h_f<=0)&&(h <= 0.4) then ' a quarter hour'
                  elsif (h_f<=0)&&(h <= 0.6) then ' a half hour'
                  elsif (h_f<=0)&&(h <= 0.9) then ' three quarters of an hour'
                  elsif (h_f==1)&&(h <= 0.2) then ' hour'
                  elsif (h_f>=2)&&(h <= 0.2) then ' hours'
                  elsif (h_f>=1)&&(h <= 0.4) then ' and a quarter hours'   
                  elsif (h_f>=1)&&(h <= 0.6) then ' and a half hours'
                  elsif (h_f>=1)&&(h <= 1.0) then ' and three quarters hours'
                  else ' some time'
                  end

        msg_end = ' ago.'

        return msg = msg_start + msg_mid + msg_end
      rescue Exception => e;  log_exception( e, where );  end
    end #def


    ###########################################################################
    # SECTION: Twilio Helpers
    ###########################################################################

    ###########################################################################
    # Twilio-Specific 'Macro'-style Helper: Send SMS to a number
    ###########################################################################
    def send_SMS_to( number, msg )
    puts where = 'HELPER: ' + (__method__).to_s 
      begin
        puts "ATTEMPT TO SMS TO BAD NUMBER" if number.match(/\+1\d{10}\z/)==nil

        @message = $twilio_account.sms.messages.create({
              :from => ENV['TWILIO_CALLER_ID'],
              :to => number,
              :body => msg
        })
        puts "SENDING OUTGOING SMS: "+msg+" TO: "+number

      rescue Exception => e;  log_exception( e, where );  end
    end #def


    ###########################################################################
    # Twilio-Specific 'Macro'-style Helper: Send SMS back to caller
    ###########################################################################
    def reply_via_SMS( msg )
    puts where = 'HELPER: ' + (__method__).to_s
      begin
        @message = $twilio_account.sms.messages.create({
              :from => ENV['TWILIO_CALLER_ID'],
              :to => params['From'],
              :body => msg
        })
      puts "REPLYING WITH AN OUTGOING SMS: "+msg+" TO: "+params['From']

      rescue Exception => e;  log_exception( e, where );  end
    end #def


    ###########################################################################
    # Twilio-Specific 'Macro'-style Helper: Dial out to a number
    ###########################################################################
    def dial_out_to( number_to_call, route_to_execute )
    puts where = 'HELPER: ' + (__method__).to_s 
      begin
        @call = $twilio_account.calls.create({
              :from => ENV['TWILIO_CALLER_ID'],
              :to => number_to_call,
              :url => "#{SITE}" + route_to_execute
       })
       puts "DIALING OUT TO: "+number_to_call

      rescue Exception => e;  log_exception( e, where );  end
    end #def


    ###########################################################################
    # App-Specific 'Macro'-style Helper: Schedule a text-back to a num
    ###########################################################################
    def schedule_textback_to( number_to_call )
    puts where = 'HELPER: ' + (__method__).to_s 
    begin
      doc = {
       'ID' => params['From'],
       'msg' => 'Hey there! Have you rechecked your blood sugar yet? Just wanted to make sure that you addressed your low. Let us know with a normal checkin!', 
       'utc' => Time.now.to_f
      }
      DB['textbacks'].insert(doc)

      puts "Scheduling textback TO: "+number_to_call

      rescue Exception => e;  log_exception( e, where );  end
    end #def



    ###########################################################################
    # App-Specific Helper: Reset Alarm Timer for a ph_num (NOT NOW USED)
    ###########################################################################
    def reset_alarm_timer_for( ph_num )
    puts where = 'HELPER: ' + (__method__).to_s
    begin
      doc = DB['people'].find_one({'_id' => ph_num })
      doc['strikes'] = 0
      doc['timer'] = doc['alarm']
      DB['people'].save(doc)

      rescue Exception => e;  log_exception( e, where );  end
    end #def reset alarm timer


    ###########################################################################
    ###########  Application-specific Mongo DB Access Helpers  ################
    ###########################################################################


    ###########################################################################
    # Helper: Map an incoming parent's ph_num to their child's number.
    # If no mapping exists, assume caller IS (or is-to-be) a patient...
    ###########################################################################
    def patient_ph_num_assoc_wi_caller
    puts where = 'HELPER: ' + (__method__).to_s

      map_to = DB['groups'].find_one('CaregiverID' => params['From']) 

      patient_ph_num = params['From'] if (map_to==nil)
      patient_ph_num = map_to['PatientID'] if (map_to!=nil)      

      return patient_ph_num
    end #def

    ###########################################################################
    # Helper: Message entire care team
    ###########################################################################
    def msg_all_caregivers (msg)
    puts where = 'HELPER: ' + (__method__).to_s

      mapped_to = DB['groups'].find({ 'PatientID' => params['From'], 
                                      'CaregiverID' => {'$exists' => true} })
      mapped_to.each do |r|
        send_SMS_to(r['CaregiverID'], msg)
        puts "Texting" + r['CaregiverID']
        puts "With msg: " + msg
      end 
    end #def

    ###########################################################################
    # Helper: Globally message ALL caregivers in the study
    ###########################################################################
    def global_caregiver_broadcast (msg)
    puts where = 'HELPER: ' + (__method__).to_s

      mapped_to = DB['groups'].find({ 'CaregiverID' => {'$exists' => true} })
      mapped_to.each do |r|
        send_SMS_to(r['CaregiverID'], msg)
        puts "Texting" + r['CaregiverID']
        puts "With msg: " + msg
      end
    end #def

    ###########################################################################
    # Helper: Message all patients in the study who are in at least one group
    ###########################################################################
    def global_patients_with_caregivers_broadcast (msg)
    puts where = 'HELPER: ' + (__method__).to_s

      mapped_to = DB['groups'].find({ 'PatientID' => {'$exists' => true} })
      mapped_to.each do |r|
        send_SMS_to(r['PatientID'], msg)
        puts "Texting" + r['PatientID']
        puts "With msg: " + msg
      end
    end #def

    ###########################################################################
    # Helper: Message everyone in the study, period 
    ###########################################################################
    def global_broadcast (msg)
    puts where = 'HELPER: ' + (__method__).to_s

      mapped_to = DB['people'].find({ 'ID' => {'$exists' => true} })
      mapped_to.each do |r|
        send_SMS_to(r['ID'], msg)
        puts "Texting" + r['ID']
        puts "With msg: " + msg
      end
    end #def

    ###########################################################################
    # Helper: Message any one member from the care team
    ###########################################################################
    def msg_caregiver_of ( ph_num, msg )
    puts where = 'HELPER: ' + (__method__).to_s

      map = DB['groups'].find_one('PatientID' => ph_num, 
                                  'CaregiverID' => {'$exists' => true} )

      send_SMS_to( map['CaregiverID'], msg ) if map != nil
    end #def

    ###########################################################################
    #
    # One key with Mongo is to minimize the size of stored keys and val's
    # because Mongo's performance suffers unless you have enough main 
    # system memory to hold about 30 - 40% of the total size of the 
    # collections you will want to access.  
    #
    # A straightforward way to help with this is to store an "abbreviation
    # dictionary" . . .  which we can also put in Mongo!
    #
    ###########################################################################

    ###########################################################################
    # Helper: Map abbreviations to full text strings.  .  .
    ###########################################################################
    def full_string_from_abbrev( tag_abbrev_s )
    puts where = "HELPER: " + (__method__).to_s
 
      record = DB['abbrev'].find_one('abbreviation' => tag_abbrev_s)
      when_s = record['full'] if record != nil
      when_s = tag_abbrev_s if record == nil

      return when_s
    end #def


    ###########################################################################
    # Helper: Arbitrary-checkin database interactions
    ###########################################################################
    def handle_checkin(value_f, flavor_text_s)
    puts where = 'HELPER: ' + (__method__).to_s

    begin
      pts = DEFAULT_POINTS
      value_s = value_f.to_s

      doc = { 'ID' => params['From'],
              flavor_text_s => value_f,
              'flavor' => flavor_text_s, 
              'value_s' => value_s, 
              'pts' => pts,
              'utc' => @now_f
            }
      DB['checkins'].insert(doc)

      msg = "Got your checkin! Logging %.1f %s" % [value_f, flavor_text_s]

    rescue Exception => e
      msg = 'Unable to log checkin'
      log_exception( e, where )
    end

      reply_via_SMS(msg)
    end #def


    ###########################################################################
    # Helper: Handle arbitrary tagged-checkin database interactions
    ###########################################################################
    def handle_tagged_checkin(value_f, flavor_text_s, tag_s)
    puts where = 'HELPER: ' + (__method__).to_s
    begin
      pts = DEFAULT_POINTS
      value_s = value_f.to_s

      doc = { 'ID' => params['From'],
              flavor_text_s => value_f,
              'flavor' => flavor_text_s,
              'value_s' => value_s,
              'tag_s' => tag_s, 
              'pts' => pts,
              'utc' => @now_f
            }
      DB['checkins'].insert(doc)

      msg = "Got your checkin!"
      msg += " Logging %.1f %s, %s" % [value_f, flavor_text_s, tag_s]

    rescue Exception => e
      msg = 'Unable to log checkin'
      log_exception( e, where )
    end

      reply_via_SMS(msg)
    end #def




    ###########################################################################
    # Helper: Glucose-checkin database interactions
    # Give bonus points for a bg check 2-3 hours after the last meal
    # Give bonus points for a bg check 0-20 mins after a prior low bg check
    ###########################################################################
    def handle_glucose_checkin(mgdl, tag_abbrev_s)
    puts where = 'HELPER: ' + (__method__).to_s
    begin
      pts = tag_abbrev_s == '' ? 10.0 : 15.0
      msg = ''

      hi = @this_user['hi']
      lo = @this_user['lo']

      when_s = full_string_from_abbrev( tag_abbrev_s )

      last_c = last_carb_lvl_for( params['From'] )
      interval_in_hours = last_c==nil ? 0 : (@now_f - last_c['utc']) / ONE_HOUR
      pts +=10.0 if ((interval_in_hours > 1.9)&&(interval_in_hours < 3.6))
      
      DB['textbacks'].remove({'ID'=>params['From']}) if (interval_in_hours<0.2)

      last_g = last_glucose_lvl_for( params['From'] )
      g_interval_in_hours = last_g==nil ? 0 : (@now_f - last_g['utc'])/ONE_HOUR

      if (last_g == nil)
        time_of_last_checkin = 'not found'
      else
        if (last_g['mg'] < @this_user['lo'])
          msg_all_caregivers('Your child just rechecked, latest BG: '+mgdl.to_s)
          if ((interval_in_hours > 0.00)&&(interval_in_hours < 0.6))
            pts +=10.0
          end
        end #if
      end #if
      
      doc = { 'ID' => params['From'], 
              'mg' => mgdl, 
              'tag' => tag_abbrev_s, 
              'pts' => pts, 
              'utc' => @now_f 
            }
      DB['checkins'].insert(doc)

      msg = 'Thanks! Got ' +mgdl.floor.to_s+' mg/dL'
      msg += ' for your checkin!' 
      msg += ' (+' + pts.to_s + ' pts!)'

      if ((mgdl > hi)&&(last_g!=nil))
       if ((last_g['mg'] > hi) && (last_g['utc'] > @now_f-5*ONE_HOUR)) 
        msg += ' Hm, 2 highs in a row, maybe check ketones?' 
        msg_all_caregivers( 'Last 2 checkins high, latest = ' + mgdl.to_s )
       end
      elsif (mgdl < lo)
        msg += ' Hm, <'+lo.to_s+' Take tabs or juice & recheck?'
        msg_all_caregivers( 'Latest checkin was low:' + mgdl.to_s + ' but child advised to take carbs and recheck' )
        schedule_textback_to( params['From'] )
      end

    # check_for_victory( params['From'] )
    rescue Exception => e
      puts msg = 'Unable to log glucose!!!'
      log_exception( e, where )
    end
      reply_via_SMS(msg)
    end #def


    ###########################################################################
    # Helper: Lantus-checkin database interactions
    ###########################################################################
    def handle_lantus_checkin(units_f, tag_abbrev_s)
    puts where = 'HELPER: ' + (__method__).to_s
    begin
      pts = tag_abbrev_s == '' ? 20.0 : 20.0

      doc = { 'ID' => params['From'],
              'Lantus' => units_f,
              'pts' => pts,
              'utc' => @now_f
            }
      DB['checkins'].insert(doc)

      msg = "Great! Logging %.1f Lantus units. +%.0f pts " % [units_f, pts]

    rescue Exception => e
      msg = 'Unable to log Lantus'
      log_exception( e, where )
    end

      reply_via_SMS(msg)
    end #def


    ###########################################################################
    # Helper: Insulin-checkin database interactions
    #
    # If there has been an insulin checkin less than 2 hours ago, 
    # then issue a cautionary note...
    # 
    ###########################################################################
    def handle_insulin_checkin(units_f, tag_abbrev_s, ins_type='ins')
    puts where = 'HELPER: ' + (__method__).to_s
    begin
      pts = tag_abbrev_s == '' ? 5.0 : 10.0
      msg = ''

      ph_num = params['From']

      ins_type_s = full_string_from_abbrev( ins_type )
      when_s = full_string_from_abbrev( tag_abbrev_s )

      prev_i = last_insulin_lvl_for(ph_num)
      if (prev_i != nil)
        if ( (prev_i['utc'] + 2*ONE_HOUR) > @now_f ) 
          msg += 'Careful! Insulin is within 2 hours of prior dose... '
        end
      end
 
      doc = { 'ID' => params['From'],
              'units' => units_f,
              'What' => ins_type_s,
              'tag' => tag_abbrev_s, 
              'pts' => pts, 
              'utc' => @now_f
            }
      DB['checkins'].insert(doc)

      msg += 'Logging '+units_f.to_s+' units of '+ins_type_s+', '+when_s
      msg += ' +' + pts.to_s + ' pts'

    rescue Exception => e
      msg = 'Unable to log insulin'
      log_exception( e, where )
    end

      reply_via_SMS(msg)
    end #def


    ###########################################################################
    # Helper: Carb checkin database interactions
    #
    # If the last glucose report was LO and < 20 mins ago, give bonus pts.
    #
    ###########################################################################
    def handle_carb_checkin(g_f, tag_abbrev_s)
    puts where = 'HELPER: ' + (__method__).to_s
    begin
      pts = tag_abbrev_s == '' ? 5.0 : 10.0

      last_c = last_carb_lvl_for( params['From'] )
      interval_in_hours = last_c==nil ? 99 : (@now_f - last_c['utc']) / ONE_HOUR
# Disable cheat-proofing-by-carb-splitting for now
#      pts = 0.0 if (interval_in_hours < 1.0)
   
      lo = @this_user['lo']
      msg = ''

      when_s = full_string_from_abbrev( tag_abbrev_s )

      last_level = last_glucose_lvl_for( params['From'] )
      if (last_level == nil)
        time_of_last_checkin = 'never'
      else
        interval_in_mins = (Time.now.to_f - last_level['utc']) / 60.00
        pts +=10.0 if ((interval_in_mins < 20.0)&&(last_level['mg'] < lo))
        msg += ' [*Bonus Points* for counteracting a low bg] '
      end #if

      doc = {
              'ID' => params['From'],
              'g' => g_f,
              'tag' => tag_abbrev_s,
              'pts' => pts,
              'utc' => @now_f
            }
      DB['checkins'].insert(doc)

      msg = 'Logged '+g_f.floor.to_s+'g carbs, '+when_s+', +'+pts.to_s+'pts'

    rescue Exception => e
      msg = 'Unable to log carbs'
      log_exception( e, where )
    end

      reply_via_SMS(msg)
    end #def


    ###########################################################################
    # Helper: Typo Deletion (a.k.a. A "Backspace Key")
    # If the user notices a typo immediately, we can correct the prior number
    ###########################################################################
    def delete_last_checkin()
    puts where = 'HELPER: ' + (__method__).to_s
    begin
      db_cursor = DB['checkins'].find({'ID' => params['From']})
      db_record = db_cursor.sort('utc' => -1).limit(1).first

      if (db_record==nil)

        msg = 'No checkins yet, or all checkins have been deleted.'

      else

        DB['checkins'].remove({ '_id' => db_record['_id'] })

        if (db_record['What'] == nil)
          msg = 'Removing last checkin!'
        else
          msg = 'Removing last checkin: '+db_record['What'].to_s
        end #if

      end #if

    rescue Exception => e
      msg = 'Unable to log backspace-type removal of last checkin'
      log_exception( e, where )
    end

      reply_via_SMS(msg)
    end #def

    ###########################################################################
    # Helper: Typo Correction
    # If the user notices a typo immediately, we can correct the prior number
    ###########################################################################
    def revise_last_checkin_to( new_value_s )
    puts where = 'HELPER: ' + (__method__).to_s
    begin
      new_f = Float(new_value_s)

      db_cursor = DB['checkins'].find({'ID' => params['From']})
      db_record = db_cursor.sort('utc' => -1).limit(1).first
      
      if (db_record==nil)

        msg = 'We do not have any checkins from you yet!'

      else

        id = db_record['_id']

        if (db_record['mg']!=nil)
          msg = 'Updating last sugar checkin to: '+new_f.to_s
          DB['checkins'].update({'_id' => id},
                            {"$set" => {'mg' => new_f}})
        elsif (db_record['units']!=nil)
          msg = 'Updating last insulin checkin to: '+new_f.to_s
          DB['checkins'].update({'_id' => id},
                            {"$set" => {'units' => new_f}})
        elsif (db_record['g']!=nil)
          msg = 'Updating last carb checkin to: '+new_f.to_s
          DB['checkins'].update({'_id' => id},
                            {"$set" => {'g' => new_f}})
        else
          msg = 'Sorry, cannot tell exactly what you want to update.'
        end

      end #if

    rescue Exception => e
      msg = 'Unable to log correction'
      log_exception( e, where )
    end

      reply_via_SMS(msg)
    end #def



    ###########################################################################
    # "DB Fetch" accessor-type Methods for the various tracked quantities
    ###########################################################################
    # Please Note: These may return 'nil' so check value on the other side...
    # Also Note: These return the entire record found, in a hash, not just
    #            one number or one string with the value in it
    ###########################################################################
    def last_checkin()
    puts where = 'HELPER: ' + (__method__).to_s
      db_cursor = DB['checkins'].find()
      enum = db_cursor.sort(:utc => :desc)
      last_level = enum.first

      return last_level        
    end #def

    def last_checkin_for(ph_num)
    puts where = 'HELPER: ' + (__method__).to_s
      db_cursor = DB['checkins'].find({ 'ID' => ph_num })
      enum = db_cursor.sort(:utc => :desc)
      last_level = enum.first

      return last_level        
    end #def

    def last_glucose_lvl_for(ph_num)
    puts where = 'HELPER: ' + (__method__).to_s
      db_cursor = DB['checkins'].find({ 'ID' => ph_num,
                                        'mg' => {'$exists' => true} })
      enum = db_cursor.sort(:utc => :desc)
      last_level = enum.first

      return last_level        
    end #def

    def last_insulin_lvl_for(ph_num)
    puts where = 'HELPER: ' + (__method__).to_s
      db_cursor = DB['checkins'].find({ 'ID' => ph_num, 
                                        'units' => {'$exists' => true} })
      enum = db_cursor.sort(:utc => :desc)
      last_level = enum.first

      return last_level        
    end #def

    def last_carb_lvl_for(ph_num)
    puts where = 'HELPER: ' + (__method__).to_s
      db_cursor = DB['checkins'].find({ 'ID' => ph_num,
                                        'g' => {'$exists' => true} })
      enum = db_cursor.sort(:utc => :desc)
      last_level = enum.first

      return last_level
    end #def

    def last_goal_for(ph_num)
    puts where = 'HELPER: ' + (__method__).to_s
      db_cursor = DB['checkins'].find({ 'ID' => ph_num,
                                        'goal' => {'$exists' => true} })
      enum = db_cursor.sort(:utc => :desc)
      last_level = enum.first

      return last_level
    end #def


    ###########################################################################
    ###########################################################################
    # Accessor-type Helpers returning string (msg) values
    ###########################################################################
    ###########################################################################

    ###########################################################################
    # Score Helper
    ###########################################################################
    def score_for( ph_num )
    puts where = 'HELPER: ' + (__method__).to_s
    begin
      msg = ''
      cmd = {
        aggregate: 'checkins',  pipeline: [
          {'$match' => {:ID => ph_num}},
          {'$group' => {:_id => '$ID', :pts_tot => {'$sum'=>'$pts'}}} ]
      }
      result = DB.command(cmd)['result'][0]
      score = result==nil ? DEFAULT_SCORE : result['pts_tot']
      msg = " Score: %.0f " % score
      
      last = last_goal_for( ph_num )

      goal = last==nil ? 'None.' : (last['goal']).floor
      msg += ' Goal: ' + goal.to_s

      if last != nil
        days_f = (Time.now.to_f - last['utc']) / ONE_DAY
        daystogo = 7.0 - days_f
        ptstogo = goal - score
        msg += " Only %.1f days and %d points to go!" % [daystogo, ptstogo]
      end #if last

    rescue Exception => e  
      msg += "  Goal info not available"
      log_exception( e, where )
    end

      return msg
    end #def


    ###########################################################################
    # Check-For-Victory  Helper
    ###########################################################################
    def check_for_victory( ph_num )
    puts where = 'HELPER: ' + (__method__).to_s
    begin
      msg=''
      cmd = {
        aggregate: 'checkins',  pipeline: [
          {'$match' => {:ID => ph_num}},
          {'$group' => {:_id => '$ID',:pts_tot => {'$sum'=>'$pts'}}} ]
      }
      result = DB.command(cmd)['result'][0]
      score = result==nil ? DEFAULT_SCORE : result['pts_tot']

      last = last_goal_for( ph_num )

      if last != nil
        goal = last['goal'] ==nil ? DEFAULT_GOAL : last['goal']

        days_f = (Time.now.to_f - last['utc']) / ONE_DAY

        if (score+0.001 > goal)
          msg += "GOAL ACHIEVED! %.0f points earned" % score
          msg += " in %.2f days." % days_f
          msg += '  Text, for example, goal123 to set a new goal of 123 points'

          send_SMS_to( ph_num, msg )
          msg_caregiver_of( ph_num, msg )

#         normalize_score_to_zero_for( ph_num )
          doc = {
              'ID' => ph_num,
              'victory' => score,
              'pts' => -1 * score, 
              'utc' => Time.now.to_f
          }
          DB['checkins'].insert(doc)

        end
      end #if last

      if last == nil
        send_SMS_to( ph_num, 'Congrats on getting points! Set up a goal so you can get a reward :) For example, text Goal123 to set a goal of 123 points' )
      end

    rescue Exception => e
      log_exception( e, where )
    end

    end #def


    ###########################################################################
    # Check-Progress-at-Midweek  Helper
    ###########################################################################
    def check_progress_midweek( ph_num )
    puts where = 'HELPER: ' + (__method__).to_s
    begin
      msg=''
      cmd = {
        aggregate: 'checkins',  pipeline: [
          {'$match' => {:ID => ph_num}},
          {'$group' => {:_id => '$ID',:pts_tot => {'$sum'=>'$pts'}}} ]
      }
      result = DB.command(cmd)['result'][0]
      puts score = result==nil ? DEFAULT_SCORE : result['pts_tot']

      last = last_goal_for( ph_num )

      if last == nil
        send_SMS_to( ph_num, "Morning! :)  Text Goal123 to set a goal of 123?" )
      end #if

      if last != nil
        puts goal = last['goal'] ==nil ? DEFAULT_GOAL : last['goal']

        days_f = (Time.now.to_f - last['utc']) / ONE_DAY

        if ((score+0.001 < goal)&&(days_f > 3.0))
          msg += " Good Morning!  You have earned %0.f pts..." % (score)
          msg += " Only %0.f pts more to go!" % (goal - score)
          send_SMS_to( ph_num, msg )
        end #if send report sms

      end #if last


    rescue Exception => e
      log_exception( e, where )
    end

    end #def


    ###########################################################################
    # Settings Info Helper
    ###########################################################################
    def info_for( ph_num )
    puts where = 'HELPER: ' + (__method__).to_s
    begin
      record = DB['people'].find_one({ '_id' => ph_num })
      lo_s = record['lo'] != nil ? (record['lo']).to_s  : DEFAULT_LO.to_s
      hi_s = record['hi'] != nil ? (record['hi']).to_s  : DEFAULT_HI.to_s
      alarm_s = record['alarm'] != nil ? (record['alarm']).to_s  : 'None'
      
      msg = 'Info for: ' + ph_num + '...  '
      msg += '  Lo = ' + lo_s
      msg += '  Hi =' + hi_s
      msg += '  Alarm = ' + alarm_s

    rescue Exception => e
      msg = 'Status Unavailable.'
      log_exception( e, where )
    end

      return msg
    end #def


    ###########################################################################
    # Weekly Summary Helper
    #
    # Fetch any low bg checkins and also all other checkins for the past week
    # 
    # Aggregate checkins to get totals and averages
    # 
    ###########################################################################
    def weekly_summary_for( ph_num )
    puts where = 'HELPER: ' + (__method__).to_s
    begin
      msg = ''
      lc = DB['checkins'].find({'ID' => ph_num,
                                'mg' => {'$lt' => @this_user['lo']},
                                'utc' => {'$gte' => (@now_f-ONE_WEEK)} })
      tc = DB['checkins'].find({'ID' => ph_num,
                                'utc' => {'$gte' => (@now_f-ONE_WEEK)}})
      gc = DB['checkins'].find({'ID' => ph_num,
                                'mg' => {'$lt' => 99999},
                                'utc' => {'$gte' => (@now_f-ONE_WEEK)} })
      lows = lc.count
      tot_checkins = tc.count
      glucose_checkins = gc.count

      msg = "WEEKLY STATS: "
      msg +="%d total checkins this week; " % tot_checkins
      msg +="%d total BG checks; " % glucose_checkins 
      msg +="%d low-BG events; " % lows

      cmd = {
       aggregate: 'checkins',  pipeline: [
        {'$match' => {'ID' => ph_num, 
                      'utc' => {'$gte' => (@now_f-ONE_WEEK)}}   },
        {'$group' => {:_id =>'$ID',
                      :tot_bg => {'$sum'=>'$mg'},
                      :tot_ins => {'$sum'=>'$units'},
                      :tot_carb => {'$sum'=>'$g'},
                      :earliest => {'$min'=>'$utc'}       }}       ]
      }
      tot_h = (DB.command(cmd)['result'])[0]
      tot_bg = tot_h['tot_bg']
      tot_carbs = tot_h['tot_carb']
      tot_insulin = tot_h['tot_ins']

      days_elapsed_actual = (@now_f - tot_h['earliest']) / ONE_DAY
      days_elapsed = days_elapsed_actual<1.0? 1.0 : days_elapsed_actual

      num_glucose_checkins = glucose_checkins<0.001? 1:glucose_checkins
      typ_bg = tot_bg / num_glucose_checkins

      ave_checkins = num_glucose_checkins / days_elapsed 
      ave_carbs = tot_carbs / days_elapsed 
      ave_insulin = tot_insulin / days_elapsed 
    
      msg +="%.0f ave BG; " % typ_bg
      msg += "%.1f BG checks/day, " % ave_checkins
      msg += "%.1fg carbs/day, " % ave_carbs
      msg += "%.1f units insulin/day" % ave_insulin

    rescue Exception => e
      msg += ' Not enough for a trend yet'
      log_exception( e, where )
    end

      return msg
    end #def



    ###########################################################################
    # Suppose you want to introduce folks to the app by sending them 
    # an SMS . . .  can do!  We might then like to 'recognize' them as they
    # show up / call in . . .   
    ###########################################################################
    def onboard_a_brand_new_user
    puts where = "HELPER: " + (__method__).to_s 

      begin

      doc = {
         '_id' => params['From'],
          'alarm' => DEFAULT_PANIC,
          'timer' => DEFAULT_PANIC,
          'goal' => DEFAULT_GOAL, 
          'strikes' => 0,
          'hi' => DEFAULT_HI,
          'lo' => DEFAULT_LO
        }
        DB['people'].insert(doc)

        msg = 'Welcome to the experimental tracking app!'
        msg += ' (All data sent or received is public domain.)'
        reply_via_SMS( msg )

      rescue Exception => e;  log_exception( e, where );  end
    end



    ###########################################################################
    # Cross-Application Mongo DB Access Helpers (Twilio Case)  
    ###########################################################################
    # register_email_in_db finds the 'people' entry corresponding to the
    # phone number that is calling / texting us, and adds and/or updates
    # the email on file for that person.
    ###########################################################################
    def register_email_in_db(em)
    puts where = 'HELPER: ' + (__method__).to_s

      DB['people'].update({'_id' => params['From']},
                          {"$addToSet" => {'email' => em}}, :upsert => true)
    end #def


  end #helpers
  #############################################################################
  # END OF HELPERS
  #############################################################################



  #############################################################################
  # FALLBACKS AND CALLBACKS 
  #############################################################################

  #############################################################################
  # If voice_request route can't be reached or there is a runtime exception:
  #############################################################################
  get '/voice_fallback' do
    puts "VOICE FALLBACK ROUTE"
    response = Twilio::TwiML::Response.new do |r|
      r.Say 'Goodbye for now!'
    end #response

    response.text do |format|
      format.xml { render :xml => response.text }
    end #do
  end #get


  #############################################################################
  # If the SMS_request route can't be reached or there is a runtime exception
  #############################################################################
  get '/SMS_fallback' do
    puts where = 'SMS FALLBACK ROUTE'
    begin
      doc = Hash.new
      params.each { |key, val|
        puts ('KEY:'+key+'  VAL:'+val)
        doc[key.to_s] = val.to_s
      }
      doc['utc'] = Time.now.to_f

      if ( env['sinatra.error'] == nil )
        puts 'NO SINATRA ERROR MESSAGE'
        doc['sinatra.error'] = 'None'
      else
        puts 'SINATRA ERROR \n WITH MESSAGE= ' + env['sinatra.error'].message
        doc['sinatra.error'] = env['sinatra.error'].message
      end

      DB['fallbacks'].insert(doc)

    rescue Exception => e;  log_exception( e, where );  end

  end #get


  #############################################################################
  # Whenever a voice interaction completes:
  #############################################################################
  get '/status_callback' do
    begin
      puts where = "STATUS CALLBACK ROUTE"

      puts doc = {
         'What' => 'Voice Call completed',
         'Who' => params['From'],
         'utc' => @now_f
      }
      puts DB['log'].insert(doc)

    rescue Exception => e;  log_exception( e, where );  end
  end #get


end #class TheApp
###############################################################################
# END OF TheAPP
###############################################################################

 




###############################################################################
# END OF Code
###############################################################################








###############################################################################
#                          Things to Keep in Mind
###############################################################################
#
# !: Google API scope can be a string or an array of strings
#
# !: If some but not all scopes are authorized, unauthed routes fail silently
#
# !: To list & revoke G-API: https://accounts.google.com/IssuedAuthSubTokens
#
# !: Keep in mind where the "/" is!!!  #{SITE} includes one already...
#
# !: When it's dialing OUT, the App's ph num appears as params['From'] !
#
# !: cURL does not handle Sinatra redirects - test only 1 level deep wi Curl!
#
# !: Curious fact: In local mode, Port num does not appear, triggering rescue.
#
# +: An excellent Reg-Ex tool can be found here:   http://rubular.com
#
# +: Capped collections store documents with natural order(disk order) equal
#     to insertion order
#
# +: Capped collections also have an  automatic expiry policy (roll-over)
#
# -: Capped collections are fast to write to, but cannot handle remove
#     operations or update operations that increase the size of the doc
#
# ?: http://redis.io/topics/memory-optimization
# 
# !: http://support.redistogo.com/kb/heroku/redis-to-go-on-heroku
#
# ?: logging options: https://addons.heroku.com/#logging
#
# *: To get a Mongo Shell on the MongoHQ instance: 
# /Mongo/mongodb-osx-x86_64-2.2.2/bin/mongo --host $MONGO_URL --port $MONGO_PORT -u $MONGO_USER_ID -p $MONGO_PASSWORD   $MONGO_DB_NAME
#
# http://net.tutsplus.com/tutorials/tools-and-tips/how-to-work-with-github-and-multiple-accounts/
# http://stackoverflow.com/questions/13103083/how-do-i-push-to-github-under-a-different-username
# http://stackoverflow.com/questions/3696938/git-how-do-you-commit-code-as-a-different-user
# http://stackoverflow.com/questions/15199262/managing-multiple-github-accounts-from-one-computer
# https://heroku-scheduler.herokuapp.com/dashboard
#
# http://stackoverflow.com/questions/10407638/how-do-i-pass-a-ruby-array-to-javascript-to-make-a-line-graph
# http://blog.crowdint.com/2011/03/31/make-your-sinatra-more-restful.html
# http://stackoverflow.com/questions/5015471/using-sinatra-for-larger-projects-via-multiple-files
###############################################################################


 #############################################################################
 #                                                                           #
 #                           OPEN SOURCE LICENSE                             #
 #                                                                           #
 #             Copyright (C) 2011-2013  Dr. Stephen A. Racunas               #
 #                                                                           #
 #                                                                           #
 #   Permission is hereby granted, free of charge, to any person obtaining   #
 #   a copy of this software and associated documentation files (the         #
 #   "Software"), to deal in the Software without restriction, including     #
 #   without limitation the rights to use, copy, modify, merge, publish,     #
 #   distribute, sublicense, and/or sell copies of the Software, and to      #
 #   permit persons to whom the Software is furnished to do so, subject to   # 
 #   the following conditions:                                               #
 #                                                                           #
 #   The above copyright notice and this permission notice shall be          #
 #   included in all copies or substantial portions of the Software.         #
 #                                                                           #
 #                                                                           #
 #   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,         #
 #   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF      #
 #   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  #
 #   IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY    # 
 #   CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,    #
 #   TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE       # 
 #   SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                  #
 #                                                                           #
 #############################################################################


