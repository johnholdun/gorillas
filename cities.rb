require 'twitter'

client = Twitter::REST::Client.new do |config|
  config.consumer_key        = TWITTER_CONSUMER_KEY
  config.consumer_secret     = TWITTER_CONSUMER_SECRET
  config.access_token        = TWITTER_ACCESS_TOKEN
  config.access_token_secret = TWITTER_ACCESS_TOKEN_SECRET
end

def client.get_all_tweets(user)
  collect_with_max_id do |max_id|
    options = {:count => 200, :include_rts => true}
    options[:max_id] = max_id unless max_id.nil?
    user_timeline(user, options)
  end
end

city_tweets = client.get_all_tweets 'gorillacities'; city_tweets.first

city_images = city_tweets.map do |tweet|
  begin
    [tweet.id, tweet.media.first.media_uri.to_s + ':large']
  rescue
    puts "Could not find media for tweet #{ tweet.id }"
    nil
  end
end.compact

city_images.each do |id, url|
  puts %x[curl #{ url } > cities/#{ id }.png]
end

def save_cities
  Dir.glob('cities/*.png').each do |city|
    city_id = city.match(/cities\/([0-9]+)\.png/)[1]
    rounds_dir = "rounds/#{ city_id }"

    next if Dir.exists? rounds_dir

    puts "* Generating city #{ city_id }"
    %x[mkdir #{ rounds_dir }]
    puts %x[phantomjs frames.coffee #{ city_id } rounds]

    puts "* Generating gifs"
    Dir.glob("#{ rounds_dir }/*").each do |frames|
      round = frames.split('/').last
      puts %x[gifme -w 640 -o #{ rounds_dir }/#{ round }.gif -d 3 #{ frames }/*.png]
    end
  end
end

