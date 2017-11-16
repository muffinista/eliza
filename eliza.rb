#!/usr/bin/env ruby

require 'mastodon'
require 'pry'
require 'nokogiri'
require 'wordnik'
require 'dotenv/load'

require './script.rb'

# http://www.comicartfans.com/gallerypiece.asp?piece=39755
# https://commons.wikimedia.org/wiki/File:The_doctor_is_in.png

$mutex = Mutex.new

@eliza = Script.new("script.txt")
@eliza.debug_print = true
@token = ENV["MASTODON_TOKEN"]
@last_message_at = Time.now.to_i

def run!
  client = Mastodon::REST::Client.new(base_url: 'https://botsin.space', bearer_token:@token)

  streaming_client = Mastodon::Streaming::Client.new(base_url: 'https://botsin.space', bearer_token:@token)
  streaming_client.user do |n|
    puts n.inspect
    next unless n.is_a?(Mastodon::Notification) && n.status?

    #n.account -- Account
    text = Nokogiri::HTML(n.status.content).text
    STDERR.puts text

    next unless text =~ /^@eliza/i

    $mutex.synchronize {
      @last_message_at = Time.now.to_i
    }

    text = text.gsub(/^@eliza/, "").strip
    
    user = n.account.acct
    output = @eliza.input(user, text)

    STDERR.puts output
    
    visibility = if n.status.attributes['visibility'] == "public"
                   "unlisted"
                 else
                   n.status.attributes['visibility']
                 end
    
    opts = {
      in_reply_to_id: n.status.id,
      visibility: visibility,
    }

    output = "@#{user} #{output}"
    
    response = client.create_status(output, opts[:in_reply_to_id], [], opts[:visibility])

    STDERR.puts response.inspect
  end
end

def run_bot
  $mutex.synchronize {
    @last_message_at = Time.now.to_i
  }

  streaming_thread = Thread.new {
    puts "here!"
    run!
  }

  check_thread = Thread.new {
    while(true) do
      if streaming_thread.nil? || streaming_thread.status == nil || streaming_thread.status == false
        STDERR.puts "streaming died!"
        Thread.exit
      end
      
      $mutex.synchronize {
        if Time.now.to_i - 3600 > @last_message_at
          STDERR.puts "it's been awhile, let's reboot"
          Thread.exit
        end
      }
    end
  }
 
  streaming_thread.run
  check_thread.join
end

client = Mastodon::REST::Client.new(base_url: 'https://botsin.space', bearer_token:@token)
client.create_status("The doctor is in!")

while true
  begin
    run_bot
  rescue StandardError => e
    STDERR.puts e.inspect
    sleep 2
  end
end
