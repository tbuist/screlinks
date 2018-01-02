#! /usr/bin/ruby 
# rubocop:disable Style/GlobalVars, Style/StringLiterals
require 'httparty'
require 'pry'
require 'logger'

$logger = Logger.new('./log')
$logger.level = Logger::INFO
$logger.formatter = proc do |_, datetime, _, msg|
  "#{datetime}: #{msg}\n"
end

# Parser
class Parser
  def initialize(base_url, fetch_limit, search_for, path_to, push_key)
    @base_url = base_url
    @fetch_limit = fetch_limit
    @search_for = search_for
    @path_to = path_to
    @title_regexs = @search_for.inject([]) { |arr, title| arr << regex_from_string(title) }
    @push_key = push_key
  end

  def run
    $logger.info('Running...')
    count = 0
    loop do
      response = HTTParty.get("#{@base_url}?limit=#{@fetch_limit}")
      parse(response) if response.code == 200
      count += 1
      $logger.info("API hit with response code #{response.code}")
      sleep 60
    end
  end

  def parse(response) # rubocop:disable Metrics/AbcSize
    response.dig(*@path_to[:posts]).each do |post|
      break if @latest_post_id == post.dig(*@path_to[:id])
      $logger.info('Found a new post')

      if match_regex(post.dig(*@path_to[:title]))
        pushbullet_push(post.dig(*@path_to[:title]), post.dig(*@path_to[:link]))
      end
    end

    @latest_post_id = response.dig(*@path_to[:posts]).first.dig(*@path_to[:id])
  end

  def match_regex(post_title)
    @title_regexs.any? { |regex| /#{regex}/ =~ post_title }
  end

  def regex_from_string(title)
    title.split.map do |word|
      "[#{word[0].upcase}#{word[0].downcase}]#{word[1..word.length]}"
    end.join("[ .-]*")
  end

  def pushbullet_push(title, link)
    res = HTTParty.post(
      'https://api.pushbullet.com/v2/pushes',
      body: { body: link, title: title, type: 'link', url: link }.to_json,
      headers: { 'Content-Type' => 'application/json', 'Access-Token' => @push_key }
    )
    $logger.info("Pushed notification for '#{title}' and got response #{res.code}")
  end
end

def get_trakt_shows(api_key)
  headers = { 'Content-Type' => 'application/json',
              'trakt-api-version' => '2',
              'trakt-api-key' => api_key }
  response = HTTParty.get('https://api.trakt.tv/users/tbuist/collection/shows',
                          headers: headers)
  raise "Error fetching Trakt.tv Shows" unless response.code == 200
  raise "Didn't find any shows for which to watch" if response.empty?
  $logger.info("Found #{response.length} shows to watch for")
  response.map { |entry| entry["show"]["title"] }
end

base_url = 'https://www.reddit.com/r/megalinks/new/.json'
fetch_limit = 10
path_to = {
  posts: %w[data children],
  id: %w[data id],
  title: %w[data title],
  link: %w[data url]
}

# ARGV[0] = pushbullet, ARGV[1] = trakt.tv
raise 'One or both API Keys not given' unless ARGV[0] && ARGV[1]
search_for = get_trakt_shows(ARGV[1])

# Search for additional things by including them in text files by line and add as cmd line arg
counter = 0
ARGV.each_with_index do |arg, idx|
  next if idx < 2
  File.foreach(arg).with_index do |line, line_num|
    search_for << line.strip
    counter = counter + 1
  end
end
puts "Found #{counter} extra things to search for"

parser = Parser.new(base_url, fetch_limit, search_for, path_to, ARGV[0])
parser.run
