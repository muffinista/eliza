#!/usr/bin/env ruby

require 'mastodon'
require 'pry'
require 'nokogiri'
require 'wordnik'

require './script.rb'

Wordnik.configure do |config|
  config.api_key = 'ea70a61690a8b6d00417242c4bf2496222a195c602710ae28'
  config.logger = Logger.new('/dev/null')
end


@eliza = Script.new("script.txt")
@eliza.debug_print = true
@token = ENV["MASTODON_TOKEN"]

def run!
  client = Mastodon::REST::Client.new(base_url: 'https://botsin.space', bearer_token:@token)

  streaming_client = Mastodon::Streaming::Client.new(base_url: 'https://botsin.space', bearer_token:@token)
  streaming_client.user do |n|
    next unless n.is_a?(Mastodon::Notification) && n.status?
    puts n.inspect

    #n.account -- Account
    text = Nokogiri::HTML(n.status.content).text

    next unless text =~ /^@eliza/i

    text = text.gsub(/^@eliza/, "").strip
    
    user = n.account.username
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
    
    
    #def create_status(text, in_reply_to_id = nil, media_ids = [], visibility = nil)  
    response = client.create_status(output, opts[:in_reply_to_id], [], opts[:visibility])

    STDERR.puts response.inspect
  end
end


while true
  begin
    run!
  rescue StandardError => e
    STDERR.puts e.inspect
    sleep 2
  end
end
